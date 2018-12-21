//
//  CtripPaymentSDKKVO.h
//  MYKVO
//
//  Created by zf on 2018/12/21.
//  Copyright © 2018 zf. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CPaymentKVONotificationKeyPathKey;

typedef void (^CPaySDKKVONotificationBlock)(id _Nullable observer, id object, NSDictionary<NSKeyValueChangeKey, id> *change);

@interface CtripPaymentSDKKVO : NSObject

//用来执行block,action 等的对象
@property (nullable, nonatomic, weak, readonly) id observer;

+ (instancetype)controllerWithObserver:(nullable id)observer;

- (instancetype)initWithObserver:(nullable id)observer;

- (void)observe:(nullable id)object
        keyPaths:(NSArray<NSString *> *)keyPaths
        options:(NSKeyValueObservingOptions)options
          block:(CPaySDKKVONotificationBlock)block;

- (void)observe:(nullable id)object
        keyPaths:(NSArray<NSString *> *)keyPaths
        options:(NSKeyValueObservingOptions)options
          action:(SEL)action;

- (void)observe:(nullable id)object
        keyPaths:(NSArray<NSString *> *)keyPaths
        options:(NSKeyValueObservingOptions)options
        context:(nullable void *)context;
- (void)unobserve:(id)object;
- (void)unobserveAll;
@end

NS_ASSUME_NONNULL_END
