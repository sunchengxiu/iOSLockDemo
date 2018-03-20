# ios 线程锁
为什么要有线程锁，一般情况下我们是不允许多个线程同时读写操作的，为了保证线程安全，我们必须让一个线程做完，才能让另一个线程去操作。
下面我们就以卖票为例，因为卖票是最典型的例子。

```

- (void)viewDidLoad {
    self.tickets = 10;
    [super viewDidLoad];
    
    // 线程1
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self sale];
    });
    // 线程2
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self sale];
    });
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


```

看一下控制台的log


```

2018-03-20 10:13:22.312920+0800 lock[43439:1812533] 剩余票数---8张
2018-03-20 10:13:22.814260+0800 lock[43439:1812533] 剩余票数---7张
2018-03-20 10:13:22.814276+0800 lock[43439:1812534] 剩余票数---6张
2018-03-20 10:13:23.319800+0800 lock[43439:1812533] 剩余票数---4张
2018-03-20 10:13:23.319800+0800 lock[43439:1812534] 剩余票数---5张
2018-03-20 10:13:23.822148+0800 lock[43439:1812534] 剩余票数---2张
2018-03-20 10:13:23.822148+0800 lock[43439:1812533] 剩余票数---3张
2018-03-20 10:13:24.323111+0800 lock[43439:1812533] 剩余票数---1张
2018-03-20 10:13:24.323111+0800 lock[43439:1812534] 剩余票数---0张
2018-03-20 10:13:24.828316+0800 lock[43439:1812534] 卖光了
2018-03-20 10:13:24.828313+0800 lock[43439:1812533] 卖光了


```

这还是加了0.5秒的延迟。

## @synchronized

@synchronize 是我们平时用的最多的锁，又叫互互斥锁，
性能较差，不推荐使用


### 用法

```
@synchronized(OC 对象) {
       被加锁的代码，注意这里面的内容，代码越少越好，也不要太耗时，否则性能会更加的差。
  }

```

### 优缺点

不用显示的去创建锁对象，一般会使用self来加锁，注意这个对象必须是全局唯一的，必须保证多个线程同时访问的时候，@synchronize（OC对象）,必须保证这个对象是相同的。

### 示例代码

```
- (void)synchronizeSale{
    while (true) {
        @synchronized(self){
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
}

```



## NSLock

NSLock,普通锁，要注意的是，不能多次调用lock，否则会造成死锁。

### 用法

```
	[self.lock lock];
    [self.lock unlock];

```

### 优缺点

API 比较简单，只需要在加锁的地方lock，解锁的地方unlock就可以了，缺点是用不好会造成死锁，尤其是在循环里面。

### 示例代码

```
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

```


## dispatch_semaphore_t（信号量）

信号量也是本人平时用到的最多的锁，性能比较好，用法也不是太难

### 用法

```
dispatch_semaphore_create
dispatch_semaphore_wait
dispatch_semaphore_signal

```

### 优缺点

要设置好信号量的数值，当wait的时候，信号量会减一，当signal的时候，信号量会加一，当为0的时候，线程会一直处于等待状态，如果dispatch_semaphore_wait(signal, overTime);后面的overTime给了一定的数值，那么会等待这个时间之后，去释放线程继续执行，如果给的是forever，那么线程会一直卡在这里.


### 示例代码

```

- (void)viewDidLoad {
    self.tickets = 10;
    [super viewDidLoad];
    self.lock = [[NSLock alloc] init];
    self.semaphore = dispatch_semaphore_create(1);
    // 线程1
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self semSale];
    });
    // 线程2
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self semSale];
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

```

### 原理

我们一开始给的信号量为1，当有一个线程进来买票的时候，这个时候执行了wait，这个时候信号量会减一，然后自己开始买票，假设这时候，又有一个线程进来买票了，有执行到wait了，发现这时候信号量为0，就一直等待，知道上一个人买到票了，买到票之后把信号量加一，执行signal，这个人才可以买。

### log

看一下输出和线程

```
2018-03-20 13:50:43.325467+0800 lock[65191:2429714] 剩余票数---9张
2018-03-20 13:50:43.325657+0800 lock[65191:2429714] <NSThread: 0x60400027dc00>{number = 3, name = (null)}
2018-03-20 13:50:43.829059+0800 lock[65191:2429712] 剩余票数---8张
2018-03-20 13:50:43.829512+0800 lock[65191:2429712] <NSThread: 0x60c000066640>{number = 4, name = (null)}
2018-03-20 13:50:44.332722+0800 lock[65191:2429714] 剩余票数---7张
2018-03-20 13:50:44.333094+0800 lock[65191:2429714] <NSThread: 0x60400027dc00>{number = 3, name = (null)}
2018-03-20 13:50:44.837398+0800 lock[65191:2429712] 剩余票数---6张
2018-03-20 13:50:44.837762+0800 lock[65191:2429712] <NSThread: 0x60c000066640>{number = 4, name = (null)}
2018-03-20 13:50:45.343206+0800 lock[65191:2429714] 剩余票数---5张
2018-03-20 13:50:45.343577+0800 lock[65191:2429714] <NSThread: 0x60400027dc00>{number = 3, name = (null)}
2018-03-20 13:50:45.848952+0800 lock[65191:2429712] 剩余票数---4张
2018-03-20 13:50:45.849332+0800 lock[65191:2429712] <NSThread: 0x60c000066640>{number = 4, name = (null)}
2018-03-20 13:50:46.353070+0800 lock[65191:2429714] 剩余票数---3张
2018-03-20 13:50:46.353349+0800 lock[65191:2429714] <NSThread: 0x60400027dc00>{number = 3, name = (null)}
2018-03-20 13:50:46.854531+0800 lock[65191:2429712] 剩余票数---2张
2018-03-20 13:50:46.854909+0800 lock[65191:2429712] <NSThread: 0x60c000066640>{number = 4, name = (null)}
2018-03-20 13:50:47.355823+0800 lock[65191:2429714] 剩余票数---1张
2018-03-20 13:50:47.356235+0800 lock[65191:2429714] <NSThread: 0x60400027dc00>{number = 3, name = (null)}
2018-03-20 13:50:47.857671+0800 lock[65191:2429712] 剩余票数---0张
2018-03-20 13:50:47.858070+0800 lock[65191:2429712] <NSThread: 0x60c000066640>{number = 4, name = (null)}
2018-03-20 13:50:47.858392+0800 lock[65191:2429714] 卖光了


```

### 实例二

```
- (void)semExample{
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"我是线程一");
        dispatch_semaphore_wait(self.semaphore, time);
        NSLog(@"线程一：我应该延迟三秒才执行");
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

```

猜猜打印的结果是什么，注意！！！！！！我有个延迟三秒，看一下log

```

2018-03-20 13:59:41.890103+0800 lock[65291:2452735] 我是线程一
2018-03-20 13:59:41.890125+0800 lock[65291:2452738] 我是线程二
2018-03-20 13:59:41.890304+0800 lock[65291:2452735] 线程一：我应该延迟三秒才执行
2018-03-20 13:59:41.890451+0800 lock[65291:2452735] 线程一结束
2018-03-20 13:59:41.890459+0800 lock[65291:2452738] 线程二：我应该延迟三秒才执行
2018-03-20 13:59:41.890610+0800 lock[65291:2452738] 线程二结束


```

结果是我们达到了阻塞线程，按顺序执行的效果，但是，并没有达到预期的延迟三秒执行，为什么呢，因为我们在创建信号量的时候，是这样的，
`` self.semaphore = dispatch_semaphore_create(1); ``
给的信号量是一，当执行线程一的时候发现信号量大于一，会减一继续执行下面的代码，而走到线程二的时候，这时候信号量为0，阻塞了，当线程一single的时候，线程二才知道，才会继续往下走。这时候，我们将信号量改为0再试一下

`` self.semaphore = dispatch_semaphore_create(0); ``

```
2018-03-20 14:04:46.171476+0800 lock[65346:2465773] 我是线程二
2018-03-20 14:04:46.171477+0800 lock[65346:2465771] 我是线程一
2018-03-20 14:04:49.175810+0800 lock[65346:2465773] 线程二：我应该延迟三秒才执行
2018-03-20 14:04:49.175812+0800 lock[65346:2465771] 线程一：我应该延迟三秒才执行
2018-03-20 14:04:49.176171+0800 lock[65346:2465773] 线程二结束
2018-03-20 14:04:49.176171+0800 lock[65346:2465771] 线程一结束
```
这个时候可见，我们的三秒就起作用了。

## NSRecursiveLock(递归锁)

我们在用递归的时候如果用普通锁进行加锁的话，会造成死锁

```
- (void)recersiveLock{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        static void (^recursiveLockBlock)(int);
        recursiveLockBlock= ^(int tickets){
            [self.lock lock];
            if (tickets > 0) {
                NSLog(@"卖出第%d张图片",tickets);
                sleep(0.5);
                tickets --;
                recursiveLockBlock(tickets);
            }
            [self.lock unlock];
        };
        recursiveLockBlock(10);
    });
}

```

这里面的lock是NSLock，这个时候会显现程序死掉，而我们将它改成递归锁，

```

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

```

### 优缺点

递归锁可以在同一个线程中被同时使用多次而不会造成死锁，普通锁会造成死锁.

## pthread_mutex 互斥锁

我得偶像YY大神在一篇文章中写到，[不再安全的 OSSpinLock](https://blog.ibireme.com).并且也将自己的开源框架 [【YYKit】](https://github.com/ibireme/YYKit)中的锁换成``pthread_mutex``锁，

### 示例代码

```
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

```

### log

```
2018-03-20 14:50:00.050777+0800 lock[65841:2584462] 我是线程一
2018-03-20 14:50:01.051019+0800 lock[65841:2584463] 我是线程二
2018-03-20 14:50:03.055390+0800 lock[65841:2584462] 线程一进行中
2018-03-20 14:50:03.055780+0800 lock[65841:2584462] 线程一结束
2018-03-20 14:50:03.055813+0800 lock[65841:2584463] 线程二进行中
2018-03-20 14:50:03.056024+0800 lock[65841:2584463] 线程二结束

```

## pthread_mutex 递归锁

pthread_mutex 依然可以实现递归锁的效果

和上边讲到的递归锁差不多，但是性能要高于普通的递归锁

```
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

```

```
2018-03-20 14:55:53.576672+0800 lock[65883:2600498] 卖出第10张图片
2018-03-20 14:55:53.576892+0800 lock[65883:2600498] 卖出第9张图片
2018-03-20 14:55:53.577093+0800 lock[65883:2600498] 卖出第8张图片
2018-03-20 14:55:53.577206+0800 lock[65883:2600498] 卖出第7张图片
2018-03-20 14:55:53.577324+0800 lock[65883:2600498] 卖出第6张图片
2018-03-20 14:55:53.577939+0800 lock[65883:2600498] 卖出第5张图片
2018-03-20 14:55:53.578270+0800 lock[65883:2600498] 卖出第4张图片
2018-03-20 14:55:53.578442+0800 lock[65883:2600498] 卖出第3张图片
2018-03-20 14:55:53.578601+0800 lock[65883:2600498] 卖出第2张图片
2018-03-20 14:55:53.578719+0800 lock[65883:2600498] 卖出第1张图片

```

## NSCondition

NSCondition主要的方法有，wait，waitUntilDate，signal，broadcast，signal可以唤醒一个锁，broadcast可以唤醒所有的锁，这个锁一般用的较少

```
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
        [condition signal];
    });
}

```

当wait的时候，线程处于等待状态，当signal的时候会唤醒一个线程

```
2018-03-20 15:05:46.795907+0800 lock[66014:2628632] 我是线程一
2018-03-20 15:05:46.795907+0800 lock[66014:2628633] 我是线程二
2018-03-20 15:05:48.800519+0800 lock[66014:2628636] 唤醒一个线程
2018-03-20 15:05:48.800938+0800 lock[66014:2628632] 线程一进行中
2018-03-20 15:05:48.801162+0800 lock[66014:2628632] 线程一结束

```

如果将`` [condition signal]; `` 换成 `` [condition broadcast]; ``

```
2018-03-20 15:07:19.755079+0800 lock[66046:2633741] 我是线程二
2018-03-20 15:07:19.755079+0800 lock[66046:2633744] 我是线程一
2018-03-20 15:07:21.755937+0800 lock[66046:2633742] 唤醒一个线程
2018-03-20 15:07:21.756344+0800 lock[66046:2633744] 线程一进行中
2018-03-20 15:07:21.756609+0800 lock[66046:2633741] 线程二进行中
2018-03-20 15:07:21.756609+0800 lock[66046:2633744] 线程一结束
2018-03-20 15:07:21.756828+0800 lock[66046:2633741] 线程二结束

```

可见所有的线程都进行了。

## NSConditionLock 条件锁

条件锁有一个锁标识，在上锁的时候回去找这个标识，有个有这个标识，就会上锁成功，然后解锁，去给下一个标识，如果接下来的线程在上锁的时候用到这个标识，那么那个线程也会去进行，

```
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

```

```
2018-03-20 15:17:38.104964+0800 lock[66233:2669009] 我是线程1
2018-03-20 15:17:38.105214+0800 lock[66233:2669008] 我是线程3
2018-03-20 15:17:38.105362+0800 lock[66233:2669007] 我是线程2

```

如果我们把线程1的`` [condition tryLockWhenCondition:1] `` 改为 `` [condition tryLockWhenCondition:0] ``那么所有的线程都会上锁失败，无法进行。因为没有找到锁标识

```
2018-03-20 15:18:43.582660+0800 lock[66258:2672368] 线程一等待锁失败

```

## OSSpinLock 自旋锁

自旋锁是性能最好的锁但是，已经不再安全，上面说的YY大神已经在他们文章中说到，有兴趣的同学可以去看一下,苹果现在也不让我们使用了，可以用 `` pthread_mutex ``来代替自旋锁，性能对比，见YY大神写的demo，[yy](https://github.com/ibireme/tmp),自旋锁在lock的时候会大于0.unlock的状态下为0.

```
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

```

只要让线程一先执行，并且加锁，那么线程二，线程三就会等待，等待线程一执行完之后，才会继续执行。

```

2018-03-20 15:33:42.383240+0800 lock[66459:2713343] 我是线程1
2018-03-20 15:33:43.383304+0800 lock[66459:2713341] 我是线程2
2018-03-20 15:33:44.384517+0800 lock[66459:2713342] 我是线程3
2018-03-20 15:33:45.387477+0800 lock[66459:2713343] 线程1进行中
2018-03-20 15:33:45.387844+0800 lock[66459:2713343] 线程1结束
2018-03-20 15:33:45.403146+0800 lock[66459:2713342] 线程3进行中
2018-03-20 15:33:45.403481+0800 lock[66459:2713342] 线程3结束
2018-03-20 15:33:45.444178+0800 lock[66459:2713341] 线程2进行中
2018-03-20 15:33:45.444510+0800 lock[66459:2713341] 线程2结束

```

# 以上就是个人对ios八种锁的理解，如果有不对的地方一定要指正，告诉我，这样大家才能共同进步，谢谢

[【DEMO】](https://github.com/sunchengxiu/iOSLockDemo.git)









