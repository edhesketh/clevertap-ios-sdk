//
//  CTVariables.m
//  CleverTapSDK
//
//  Created by Nikola Zagorchev on 12.03.23.
//  Copyright © 2023 CleverTap. All rights reserved.
//

#import "CTVariables.h"
#import "CTConstants.h"
#import "CTUtils.h"

@interface CTVariables()
@property (nonatomic, strong) CleverTapInstanceConfig *config;
@property (nonatomic, strong) CTDeviceInfo *deviceInfo;

@property(strong, nonatomic) NSMutableArray *variablesChangedBlocks;
@property(strong, nonatomic) NSMutableArray *onceVariablesChangedBlocks;

@end

@implementation CTVariables
// TODO: Linting: Brackets and spaces consistency
- (instancetype)initWithConfig:(CleverTapInstanceConfig *)config deviceInfo: (CTDeviceInfo*)deviceInfo {
    if ((self = [super init])) {
        self.varCache = [[CTVarCache alloc] initWithConfig:config deviceInfo:deviceInfo];
    }
    return self;
}

- (CTVar *)define:(NSString *)name with:(NSObject *)defaultValue kind:(NSString *)kind
{
    if ([CTUtils isNullOrEmpty:name]) {
        CleverTapLogDebug(_config.logLevel, @"%@: Empty name provided as parameter while defining a variable.", self);
        return nil;
    }

    if ([name hasPrefix:@"."] || [name hasSuffix:@"."]) {
        CleverTapLogDebug(_config.logLevel, @"%@: Variable name starts or ends with a `.` which is not allowed.", self);
        return nil;
    }

    @synchronized (self.varCache.vars) {
        CT_TRY
        CTVar *existing = [self.varCache getVariable:name];
        if (existing) {
            return existing;
        }
        CT_END_TRY
        NSArray<NSString *> *nameComponents = [self.varCache getNameComponents:name];
        CTVar *var = [[CTVar alloc] initWithName:name
                                  withComponents:nameComponents
                                withDefaultValue:defaultValue
                                        withKind:kind
                                        varCache:self.varCache];
        return var;
    }
}

- (void)handleVariablesResponse:(NSDictionary *)varsResponse
{
    if (varsResponse) {
        [[self varCache] setHasVarsRequestCompleted:YES];
        NSDictionary *values = [self unflatten:varsResponse];
        [[self varCache] applyVariableDiffs:values];
        [self triggerVariablesChanged];
        [self triggerFetchVariables:YES];
    }
}

- (void)handleVariablesError
{
    if (![[self varCache] hasVarsRequestCompleted]) {
        [[self varCache] setHasVarsRequestCompleted:YES];
        [self triggerVariablesChanged];
    } else {
        [self triggerFetchVariables:NO];
    }
}

// TODO: callback is overridden after second call if first is not ready yet
- (void)triggerFetchVariables:(BOOL)success {
    if (self.fetchVariablesBlock) {
        CleverTapFetchVariablesBlock block = [self.fetchVariablesBlock copy];
        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(success);
            });
        } else {
            block(success);
        }
        
        self.fetchVariablesBlock = nil;
    }
}

- (void)triggerVariablesChanged
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self triggerVariablesChanged];
        });
        return;
    }
    
    for (CleverTapVariablesChangedBlock block in self.variablesChangedBlocks.copy) {
        block();
    }
    
    NSArray *onceBlocksCopy;
    @synchronized (self.onceVariablesChangedBlocks) {
        onceBlocksCopy = self.onceVariablesChangedBlocks.copy;
        [self.onceVariablesChangedBlocks removeAllObjects];
    }
    for (CleverTapVariablesChangedBlock block in onceBlocksCopy) {
        block();
    }
}

- (void)onVariablesChanged:(CleverTapVariablesChangedBlock _Nonnull )block {
    
    if (!block) {
        CleverTapLogStaticDebug(@"Nil block parameter provided while calling [CleverTap onVariablesChanged].");
        return;
    }
    
    CT_TRY
    if (!self.variablesChangedBlocks) {
        self.variablesChangedBlocks = [NSMutableArray array];
    }
    [self.variablesChangedBlocks addObject:[block copy]];
    CT_END_TRY

    if ([self.varCache hasVarsRequestCompleted]) {
        block();
    }
}

- (void)onceVariablesChanged:(CleverTapVariablesChangedBlock _Nonnull )block {
    
    if (!block) {
        CleverTapLogStaticDebug(@"Nil block parameter provided while calling [CleverTap onceVariablesChanged].");
        return;
    }
    
    if ([self.varCache hasVarsRequestCompleted]) {
        block();
    } else {
        CT_TRY
        static dispatch_once_t onceBlocksToken;
        dispatch_once(&onceBlocksToken, ^{
            self.onceVariablesChangedBlocks = [NSMutableArray array];
        });
        @synchronized (self.onceVariablesChangedBlocks) {
            [self.onceVariablesChangedBlocks addObject:[block copy]];
        }
        CT_END_TRY
    }
}

- (NSDictionary*)varsPayload {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"type"] = CT_PE_VARS_PAYLOAD_TYPE;
    
    NSMutableDictionary *allVars = [NSMutableDictionary dictionary];
    
    [self.varCache.vars
     enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, CTVar * _Nonnull variable, BOOL * _Nonnull stop) {
        
        NSMutableDictionary *varData = [NSMutableDictionary dictionary];
        
        if ([variable.defaultValue isKindOfClass:[NSDictionary class]]) {
            NSDictionary *flattenedMap = [self flatten:variable.defaultValue varName:variable.name];
            [allVars addEntriesFromDictionary:flattenedMap];
        }
        else {
            if ([variable.kind isEqualToString:CT_KIND_INT] || [variable.kind isEqualToString:CT_KIND_FLOAT]) {
                varData[CT_PE_VAR_TYPE] = CT_PE_NUMBER_TYPE;
            }
            else if ([variable.kind isEqualToString:CT_KIND_BOOLEAN]) {
                varData[CT_PE_VAR_TYPE] = CT_PE_BOOL_TYPE;
            }
            else {
                varData[CT_PE_VAR_TYPE] = variable.kind;
            }
            varData[CT_PE_DEFAULT_VALUE] = variable.defaultValue;
            allVars[key] = varData;
        }
    }];
    payload[CT_PE_VARS_PAYLOAD_KEY] = allVars;
    
    return payload;
}

- (NSDictionary*)flatten:(NSDictionary*)map varName:(NSString*)varName {
    NSMutableDictionary *varsPayload = [NSMutableDictionary dictionary];
    
    [map enumerateKeysAndObjectsUsingBlock:^(NSString*  _Nonnull key, id  _Nonnull value, BOOL * _Nonnull stop) {
        if ([value isKindOfClass:[NSString class]] ||
            [value isKindOfClass:[NSNumber class]]) {
            NSString *flatKey = [NSString stringWithFormat:@"%@.%@", varName, key];
            varsPayload[flatKey] = @{ CT_PE_DEFAULT_VALUE: value };
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            NSString *flatKey = [NSString stringWithFormat:@"%@.%@", varName, key];
            NSDictionary* flattenedMap = [self flatten:value varName:flatKey];
            [varsPayload addEntriesFromDictionary:flattenedMap];
        }
    }];
    
    return varsPayload;
}

- (NSDictionary*)unflatten:(NSDictionary*)flatDictionary {
    if (!flatDictionary) {
        return nil;
    }
    
    NSMutableDictionary *unflattenVars = [NSMutableDictionary dictionary];
    [flatDictionary enumerateKeysAndObjectsUsingBlock:^(NSString* _Nonnull key, id  _Nonnull value, BOOL * _Nonnull stop) {
        if ([key containsString:@"."]) {
            NSArray *components = [self.varCache getNameComponents:key];
            NSMutableDictionary *currentMap = unflattenVars;
            NSString *lastComponent = [components lastObject];
            
            for (int i = 0; i < components.count - 1; i++) {
                NSString *component = components[i];
                if (!currentMap[component]) {
                    NSMutableDictionary *nestedMap = [NSMutableDictionary dictionary];
                    currentMap[component] = nestedMap;
                    currentMap = nestedMap;
                }
                else {
                    currentMap = ((NSMutableDictionary*)currentMap[component]);
                }
            }
            if ([currentMap isKindOfClass:[NSMutableDictionary class]]) {
                currentMap[lastComponent] = value;
            }
        }
        else {
            unflattenVars[key] = value;
        }
    }];
    
    return unflattenVars;
}

@end
