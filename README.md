# appreciate for your star

> 开启录音
```
[XBEchoCancellation.shared startService];
[XBEchoCancellation.shared startInput];
XBEchoCancellation.shared.bl_input = ^(AudioBufferList *bufferList) {
     NSData *pcmData = [NSData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
     [self playData:pcmData];
 };
```

> 播放录音
```
- (void)playData:(NSData *)data {
    dispatch_async(self.playQueue, ^{
        [self.audioQueuePlay playWithData:data];
    });
}
```
