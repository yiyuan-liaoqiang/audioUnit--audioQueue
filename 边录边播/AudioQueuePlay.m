//
//  AudioQueuePlay.m
//  SureBus SC
//
//  Created by LiaoQiang on 2019/5/31.
//  Copyright © 2019 欧阳凯. All rights reserved.
//

#import "AudioQueuePlay.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define MIN_SIZE_PER_FRAME 4096   //每个包的大小,室内机要求为960,具体看下面的配置信息
#define QUEUE_BUFFER_SIZE  3      //缓冲器个数
#define SAMPLE_RATE        16000  //采样频率

@implementation AudioQueuePlay
{
    AudioQueueRef audioQueue;                                 //音频播放队列
    AudioStreamBasicDescription _audioDescription;
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; //音频缓存
    BOOL audioQueueBufferUsed[QUEUE_BUFFER_SIZE];             //判断音频缓存是否在使用
    NSLock *sysnLock;
    NSMutableData *tempData;
    OSStatus osState;
    Byte *pcmDataBuffer;//pcm的读文件数据区
}

- (void)resetPlay {
    if (audioQueue != nil) {
        AudioQueueReset(audioQueue);
    }
}

#pragma mark - 提前设置AVAudioSessionCategoryMultiRoute 播放和录音
+ (void)initialize
{
    NSError *error = nil;
    //只想要播放:AVAudioSessionCategoryPlayback
    //只想要录音:AVAudioSessionCategoryRecord
    //想要"播放和录音"同时进行 必须设置为:AVAudioSessionCategoryMultiRoute 而不是AVAudioSessionCategoryPlayAndRecord(设置这个不好使)
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryMultiRoute error:&error];
    if (!ret) {
        NSLog(@"设置声音环境失败");
        return;
    }
    //启用audio session
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret)
    {
        NSLog(@"启动失败");
        return;
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        sysnLock = [[NSLock alloc]init];
        pcmDataBuffer = malloc(MIN_SIZE_PER_FRAME);
        //设置音频参数 具体的信息需要问后台
        _audioDescription.mSampleRate = SAMPLE_RATE/2;
        _audioDescription.mFormatID = kAudioFormatLinearPCM;
        _audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        //1单声道
        _audioDescription.mChannelsPerFrame = 1;
        //每一个packet一侦数据,每个数据包下的桢数，即每个数据包里面有多少桢
        _audioDescription.mFramesPerPacket = 1;
        //每个采样点16bit量化 语音每采样点占用位数
        _audioDescription.mBitsPerChannel = 16;
        _audioDescription.mBytesPerFrame = (_audioDescription.mBitsPerChannel / 8) * _audioDescription.mChannelsPerFrame;
        //每个数据包的bytes总数，每桢的bytes数*每个数据包的桢数
        _audioDescription.mBytesPerPacket = _audioDescription.mBytesPerFrame * _audioDescription.mFramesPerPacket;
        
        // 使用player的内部线程播放 新建输出
        AudioQueueNewOutput(&_audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, 0, 0, &audioQueue);
        
        // 设置音量
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 0.3);
        
        // 初始化需要的缓冲区
        for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
            audioQueueBufferUsed[i] = false;
            osState = AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);
        }
        
        osState = AudioQueueStart(audioQueue, NULL);
        if (osState != noErr) {
            NSLog(@"AudioQueueStart Error");
        }
    }
    return self;
}

- (AudioQueueBufferRef)getNotUsedBuffer
{
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        if (NO == audioQueueBufferUsed[i]) {
            audioQueueBufferUsed[i] = YES;
            return audioQueueBuffers[i];
        }
    }
    return NULL;
}

// 播放数据
-(void)playWithData:(NSData *)data
{
    [sysnLock lock];
    tempData = [NSMutableData new];
    [tempData appendData: data];
    NSUInteger len = tempData.length;
    [tempData getBytes:pcmDataBuffer length: len];
    
    AudioQueueBufferRef audioQueueBuffer = NULL;
    //获取可用buffer
    while (true) {
        [NSThread sleepForTimeInterval:0.0005];
        audioQueueBuffer = [self getNotUsedBuffer];
        if (audioQueueBuffer != NULL) {
            break;
        }
    }
    audioQueueBuffer -> mAudioDataByteSize =  (unsigned int)len;
    // 把bytes的头地址开始的len字节给mAudioData,向第i个缓冲器
    memcpy(audioQueueBuffer -> mAudioData, pcmDataBuffer, len);
    //将第i个缓冲器放到队列中,剩下的都交给系统了
    AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffer, 0, NULL);
    [sysnLock unlock];
}

static void AudioPlayerAQInputCallback(void* inUserData,AudioQueueRef audioQueueRef, AudioQueueBufferRef audioQueueBufferRef) {
    
    AudioQueuePlay* audio = (__bridge AudioQueuePlay*)inUserData;
    
    [audio resetBufferState:audioQueueRef and:audioQueueBufferRef];
}

- (void)resetBufferState:(AudioQueueRef)audioQueueRef and:(AudioQueueBufferRef)audioQueueBufferRef {
    // 防止空数据让audioqueue后续都不播放,为了安全防护一下
    if (tempData.length == 0) {
        audioQueueBufferRef->mAudioDataByteSize = 1;
        Byte* byte = audioQueueBufferRef->mAudioData;
        byte = 0;
        AudioQueueEnqueueBuffer(audioQueueRef, audioQueueBufferRef, 0, NULL);
    }
    
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        // 将这个buffer设为未使用
        if (audioQueueBufferRef == audioQueueBuffers[i]) {
            audioQueueBufferUsed[i] = false;
        }
    }
}

@end
