//
//  AudioQueuePlay.h
//  SureBus SC
//
//  Created by LiaoQiang on 2019/5/31.
//  Copyright © 2019 欧阳凯. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioQueuePlay : NSObject

// 播放的数据流数据
- (void)playWithData:(NSData *)data;

// 声音播放出现问题的时候可以重置一下
- (void)resetPlay;

// 停止播放
- (void)stop;

@end

NS_ASSUME_NONNULL_END
