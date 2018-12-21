//
//  CtripPaymentSDKKVO.m
//  MYKVO
//
//  Created by zf on 2018/12/21.
//  Copyright © 2018 zf. All rights reserved.
//

#import "CtripPaymentSDKKVO.h"
#import <pthread.h>

NSString *const CPaymentKVONotificationKeyPathKey = @"CPaymentKVONotificationKeyPathKey";

typedef NS_ENUM(uint8_t, CPaymentKVOState){
    CPaymentKVOStateInitial = 0,
    CPaymentKVOStateObserving,
    CPaymentKVOStateNotObserving,
};

@interface CPaymentKVOInfo : NSObject
{
    @public
    __weak CtripPaymentSDKKVO *_controller;
    NSString *_keyPath;
    NSKeyValueObservingOptions _options;
    SEL _action;
    void *_context;
    CPaySDKKVONotificationBlock _block;
    CPaymentKVOState _state;
}
@end

@implementation CPaymentKVOInfo

- (instancetype)initWithController:(CtripPaymentSDKKVO *)controller
                           keyPath:(NSString *)keyPath
                           options:(NSKeyValueObservingOptions)options
                             block:(nullable CPaySDKKVONotificationBlock)block
                            action:(nullable SEL)action
                           context:(nullable void *)context
{
    self = [super init];
    if (nil != self) {
        _controller = controller;
        _block = [block copy];
        _keyPath = [keyPath copy];
        _options = options;
        _action = action;
        _context = context;
    }
    return self;
}


- (NSUInteger)hash
{
    return [_keyPath hash];
}

- (BOOL)isEqual:(id)object
{
    if (nil == object) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    return [_keyPath isEqualToString:((CPaymentKVOInfo *)object)->_keyPath];
}

@end

@implementation CtripPaymentSDKKVO
{
    NSMapTable<id, NSMutableSet<CPaymentKVOInfo *> *> *_objectInfosMap;
    pthread_mutex_t _lock;
    
}


+ (instancetype)controllerWithObserver:(nullable id)observer
{
    return [[self alloc] initWithObserver:observer];
}

- (instancetype)initWithObserver:(nullable id)observer
{
    self = [super init];
    if (nil != self) {
        _observer = observer;
        NSPointerFunctionsOptions keyOptions = NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality;
        _objectInfosMap = [[NSMapTable alloc] initWithKeyOptions:keyOptions valueOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPersonality capacity:0];
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"%s",__func__);
    [self unobserveAll];
    pthread_mutex_destroy(&_lock);
}

- (void)observe:(nullable id)object
        keyPaths:(NSArray<NSString *> *)keyPaths
        options:(NSKeyValueObservingOptions)options
          block:(CPaySDKKVONotificationBlock)block
{
    if (nil == object || 0 == keyPaths.count || NULL == block) {
        return;
    }
    
    for (NSString *keyPath in keyPaths) {
        CPaymentKVOInfo *info = [[CPaymentKVOInfo alloc] initWithController:self keyPath:keyPath options:options block:block action:NULL context:NULL];
        
        [self _observe:object info:info];
    }
    
}

- (void)observe:(nullable id)object
        keyPaths:(NSArray<NSString *> *)keyPaths
        options:(NSKeyValueObservingOptions)options
         action:(SEL)action
{
    if (nil == object || 0 == keyPaths.count || NULL == action) {
        return;
    }
    for (NSString *keyPath in keyPaths) {
        CPaymentKVOInfo *info = [[CPaymentKVOInfo alloc] initWithController:self keyPath:keyPath options:options block:NULL action:action context:NULL];
        
        [self _observe:object info:info];
    }
}

- (void)observe:(nullable id)object
        keyPaths:(NSArray<NSString *> *)keyPaths
        options:(NSKeyValueObservingOptions)options
        context:(nullable void *)context
{
    if (nil == object || 0 == keyPaths.count) {
        return;
    }
    for (NSString *keyPath in keyPaths) {
        CPaymentKVOInfo *info = [[CPaymentKVOInfo alloc] initWithController:self keyPath:keyPath options:options block:NULL action:NULL context:context];
        
        [self _observe:object info:info];
    }
}

- (void)_observe:(id)object info:(CPaymentKVOInfo *)info
{
    
    pthread_mutex_lock(&_lock);
    
    NSMutableSet *infos = [_objectInfosMap objectForKey:object];
    
    CPaymentKVOInfo *existingInfo = [infos member:info];
    if (nil != existingInfo) {
   
        pthread_mutex_unlock(&_lock);
        return;
    }
    
    if (nil == infos) {
        infos = [NSMutableSet set];
        [_objectInfosMap setObject:infos forKey:object];
    }
    
    [infos addObject:info];
    
    pthread_mutex_unlock(&_lock);
    
    
    [object addObserver:self forKeyPath:info->_keyPath options:info->_options context:(__bridge void * _Nullable)(info)];
    
    if (info->_state == CPaymentKVOStateInitial) {
        info->_state = CPaymentKVOStateObserving;
    } else if (info->_state == CPaymentKVOStateNotObserving) {
        
        [object removeObserver:self forKeyPath:info->_keyPath context:info->_context];
    }
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(nullable void *)context
{
    
    CPaymentKVOInfo *info;
    
    {
        pthread_mutex_lock(&_lock);
        NSMutableSet *infos = [_objectInfosMap objectForKey:object];
        info = [infos member:(__bridge id _Nonnull)(context)];
        pthread_mutex_unlock(&_lock);
    }
    
    if (nil != info) {
        
        CtripPaymentSDKKVO *controller = info->_controller;
        if (nil != controller) {
            
            id observer = controller.observer;
            NSDictionary<NSKeyValueChangeKey, id> *changeWithKeyPath = change;
            
            if (keyPath) {
                NSMutableDictionary<NSString *, id> *mChange = [NSMutableDictionary dictionaryWithObject:keyPath forKey:CPaymentKVONotificationKeyPathKey];
                [mChange addEntriesFromDictionary:change];
                changeWithKeyPath = [mChange copy];
            }
            if (nil != observer) {
                
                if (info->_block) {
                    
                    info->_block(observer, object, changeWithKeyPath);
                } else if (info->_action) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [observer performSelector:info->_action withObject:changeWithKeyPath withObject:object];
#pragma clang diagnostic pop
                } else {
                    [observer observeValueForKeyPath:keyPath ofObject:object change:change context:info->_context];
                }
            }
        }
    }
}



- (void)unobserve:(id)object
{
    // lock
    pthread_mutex_lock(&_lock);
    
    NSMutableSet *infos = [_objectInfosMap objectForKey:object];
    
    // remove infos
    [_objectInfosMap removeObjectForKey:object];
    
    
    pthread_mutex_unlock(&_lock);
    
    // remove observer
    for (CPaymentKVOInfo *info in infos) {
        if (info->_state == CPaymentKVOStateObserving) {
            [object removeObserver:self forKeyPath:info->_keyPath context:(void *)info];
        }
        info->_state = CPaymentKVOStateNotObserving;
    }
    
}

- (void)unobserveAll
{
    // lock
    pthread_mutex_lock(&_lock);
    
    NSMapTable *objectInfoMaps = [_objectInfosMap copy];
    
    // clear table and map
    [_objectInfosMap removeAllObjects];
    
    // unlock
    pthread_mutex_unlock(&_lock);
    
    for (id object in objectInfoMaps) {
        // unobserve each registered object and infos
        NSSet *infos = [objectInfoMaps objectForKey:object];
        for (CPaymentKVOInfo *info in infos) {
            if (info->_state == CPaymentKVOStateObserving) {
                [object removeObserver:self forKeyPath:info->_keyPath context:(void *)info];
            }
            info->_state = CPaymentKVOStateNotObserving;
        }
    }
}

@end
