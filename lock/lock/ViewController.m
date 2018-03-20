//
//  ViewController.m
//  lock
//
//  Created by 孙承秀 on 2018/3/19.
//  Copyright © 2018年 孙承秀. All rights reserved.
//

#import "ViewController.h"
#import <pthread.h>
#import <libkern/OSAtomic.h>
@interface ViewController ()
/**
 票的数量
 */
@property(nonatomic , assign)NSInteger tickets;
/**
 lock
 */
@property(nonatomic , strong)NSLock *lock;
/**
 信号量
 */
@property(nonatomic , strong)dispatch_semaphore_t semaphore;
/**
 递归锁
 */
@property(nonatomic , strong)NSRecursiveLock *recursiveLock;
@end

@implementation ViewController

- (void)viewDidLoad {
    self.tickets = 10;
    [super viewDidLoad];
    self.lock = [[NSLock alloc] init];
    self.semaphore = dispatch_semaphore_create(0);
    self.recursiveLock = [[NSRecursiveLock alloc] init];
//    // 线程1
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        [self semSale];
//    });
//    // 线程2
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        [self semSale];
//    });
    
        [self spinLock];
}
- (void)spinLock{
    __block OSSpinLock spinLock = OS_SPINLOCK_INIT;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"我是线程1");
        OSSpinLockLock(&spinLock);
        sleep(3);
        NSLog(@"线程1进行中");
        OSSpinLockUnlock(&spinLock);
        NSLog(@"线程1结束");
    });
    sleep(1);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"我是线程2");
        OSSpinLockLock(&spinLock);
        NSLog(@"线程2进行中");
        OSSpinLockUnlock(&spinLock);
        NSLog(@"线程2结束");
        
    });
    sleep(1);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"我是线程3");
        OSSpinLockLock(&spinLock);
        NSLog(@"线程3进行中");
        OSSpinLockUnlock(&spinLock);
        NSLog(@"线程3结束");
    });
}
- (void)conditionLock1{
    NSConditionLock *condition = [[NSConditionLock alloc] initWithCondition:1];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([condition tryLockWhenCondition:1]) {
            NSLog(@"我是线程1");
            [condition unlockWithCondition:3];
        }
        else{
            NSLog(@"线程一等待锁失败");
        }
    });
    sleep(0.5);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [condition lockWhenCondition:2];
        NSLog(@"我是线程2");
        [condition unlockWithCondition:0];
    });
    sleep(0.5);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [condition lockWhenCondition:3];
         NSLog(@"我是线程3");
        [condition unlockWithCondition:2];
    });
}
- (void)conditionLock{
    NSCondition *condition = [NSCondition new];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"我是线程一");
        [condition lock];
        [condition wait];
        NSLog(@"线程一进行中");
        [condition unlock];
        NSLog(@"线程一结束");
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"我是线程二");
        [condition lock];
        [condition wait];
        NSLog(@"线程二进行中");
        [condition unlock];
        NSLog(@"线程二结束");
    });
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        sleep(2);
        NSLog(@"唤醒一个线程");
        [condition broadcast];
    });
}
- (void)pthreadExample{
    static pthread_mutex_t plock;
    pthread_mutex_init(&plock, NULL);//互斥锁
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"我是线程一");
        pthread_mutex_lock(&plock);
        sleep(3);
        NSLog(@"线程一进行中");
        pthread_mutex_unlock(&plock);
        NSLog(@"线程一结束");
    });
    sleep(1);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"我是线程二");
        pthread_mutex_lock(&plock);
        NSLog(@"线程二进行中");
        pthread_mutex_unlock(&plock);
        NSLog(@"线程二结束");
    });
}
- (void)pthreadLock{
    static pthread_mutex_t plock1;
    pthread_mutexattr_t attr;
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);// 递归锁
    pthread_mutex_init(&plock1, &attr);
    pthread_mutex_destroy(&plock1);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        static void (^recursiveLockBlock)(int);
        recursiveLockBlock= ^(int tickets){
            pthread_mutex_lock(&plock1);
            if (tickets > 0) {
                NSLog(@"卖出第%d张图片",tickets);
                sleep(0.5);
                tickets --;
                recursiveLockBlock(tickets);
            }
            pthread_mutex_unlock(&plock1);
        };
        recursiveLockBlock(10);
    });
}
- (void)recersiveLock{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        static void (^recursiveLockBlock)(int);
        recursiveLockBlock= ^(int tickets){
            [self.recursiveLock lock];
            if (tickets > 0) {
                NSLog(@"卖出第%d张图片",tickets);
                sleep(0.5);
                tickets --;
                recursiveLockBlock(tickets);
            }
            [self.recursiveLock unlock];
        };
        recursiveLockBlock(10);
    });
}

- (void)semExample{
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"我是线程一");
        dispatch_semaphore_wait(self.semaphore, time);
        NSLog(@"线程一：我应该延迟三秒才执行");
//        sleep(2);
        dispatch_semaphore_signal(self.semaphore);
        NSLog(@"线程一结束");
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"我是线程二");
        dispatch_semaphore_wait(self.semaphore, time);
        NSLog(@"线程二：我应该延迟三秒才执行");
        dispatch_semaphore_signal(self.semaphore);
        NSLog(@"线程二结束");
    });
}
- (void)semSale{
    while (true) {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        if (self.tickets > 0) {
            [NSThread sleepForTimeInterval:0.5];
            self.tickets --;
            NSLog(@"剩余票数---%ld张",self.tickets);
        }
        else{
            NSLog(@"卖光了");
            break;
        }
        NSLog(@"%@",[NSThread currentThread]);
        dispatch_semaphore_signal(self.semaphore);
    }
}
- (void)lockSale{
    while (true) {
        [self.lock lock];
        if (self.tickets > 0) {
            [NSThread sleepForTimeInterval:0.5];
            self.tickets --;
            NSLog(@"剩余票数---%ld张",self.tickets);
        }
        else{
            NSLog(@"卖光了");
            break;
        }
        [self.lock unlock];
    }
}
- (void)synchronizeSale{
    while (true) {
        @synchronized(self){
            if (self.tickets > 0) {
                self.tickets --;
                NSLog(@"剩余票数---%ld张",self.tickets);
            }
            else{
                NSLog(@"卖光了");
                break;
            }
        }
    }
}
- (void)sale{
    while (true) {
        [NSThread sleepForTimeInterval:0.5];
        if (self.tickets > 0) {
            self.tickets --;
            NSLog(@"剩余票数---%ld张",self.tickets);
        }
        else{
            NSLog(@"卖光了");
            break;
        }
    }
}
@end
