//
//  ViewController.m
//  边录边播
//
//  Created by LiaoQiang on 2019/6/12.
//  Copyright © 2019 LiaoQiang. All rights reserved.
//

#import "ViewController.h"
#import "XBEchoCancellation.h"
#import "AudioQueuePlay.h"

@interface ViewController ()

@property (nonatomic, strong)AudioQueuePlay *audioQueuePlay;
@property (nonatomic, strong)dispatch_queue_t playQueue;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.playQueue = dispatch_queue_create("playQueue", DISPATCH_QUEUE_SERIAL);
    self.audioQueuePlay = [[AudioQueuePlay alloc]init];
    [XBEchoCancellation.shared openEchoCancellation];
}
- (IBAction)start:(id)sender {
    dispatch_async(dispatch_get_global_queue(0,0), ^{
        [XBEchoCancellation.shared startService];
        [XBEchoCancellation.shared startInput];
        XBEchoCancellation.shared.bl_input = ^(AudioBufferList *bufferList) {
            NSData *pcmData = [NSData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
            [self playData:pcmData];
        };
    });
}

- (void)playData:(NSData *)data {
    NSLog(@"播放data -- %ld",data.length);
    dispatch_async(self.playQueue, ^{
        [self.audioQueuePlay playWithData:data];
    });
}

- (IBAction)stop:(id)sender {
    
}

@end
