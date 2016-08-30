/*
 *  Copyright 2015 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import "RTCPeerConnectionFactory+Private.h"

#import "NSString+StdString.h"
#import "RTCAVFoundationVideoSource+Private.h"
#import "RTCAudioSource+Private.h"
#import "RTCAudioTrack+Private.h"
#import "RTCMediaConstraints+Private.h"
#import "RTCMediaStream+Private.h"
#import "RTCPeerConnection+Private.h"
#import "RTCVideoSource+Private.h"
#import "RTCVideoTrack+Private.h"

@implementation RTCPeerConnectionFactory {
  std::unique_ptr<rtc::Thread> _networkThread;
  std::unique_ptr<rtc::Thread> _workerThread;
  std::unique_ptr<rtc::Thread> _signalingThread;
}

@synthesize nativeFactory = _nativeFactory;

- (instancetype)init {
  if ((self = [super init])) {
    _networkThread = rtc::Thread::CreateWithSocketServer();
    BOOL result = _networkThread->Start();
    NSAssert(result, @"Failed to start network thread.");

    _workerThread = rtc::Thread::Create();
    result = _workerThread->Start();
    NSAssert(result, @"Failed to start worker thread.");

    _signalingThread = rtc::Thread::Create();
    result = _signalingThread->Start();
    NSAssert(result, @"Failed to start signaling thread.");

    _nativeFactory = webrtc::CreatePeerConnectionFactory(
        _networkThread.get(), _workerThread.get(), _signalingThread.get(),
        nullptr, nullptr, nullptr);
    NSAssert(_nativeFactory, @"Failed to initialize PeerConnectionFactory!");
  }
  return self;
}

- (BOOL)startAecDumpWithFileDescriptor:(int)fileDescriptor
                    maxFileSizeInBytes:(int)maxFileSizeInBytes {
  // Pass the file to the recorder. The file ownership
  // is passed to the recorder, and the recorder
  // closes the file when needed.
  return _nativeFactory->StartAecDump(fileDescriptor, maxFileSizeInBytes);
}

- (void)stopAecDump {
  // The file is closed by the call below.
  _nativeFactory->StopAecDump();
}

- (RTCAudioSource *)audioSourceWithConstraints:(nullable RTCMediaConstraints *)constraints {
  std::unique_ptr<webrtc::MediaConstraints> nativeConstraints;
  if (constraints) {
    nativeConstraints = constraints.nativeConstraints;
  }
  rtc::scoped_refptr<webrtc::AudioSourceInterface> source =
      _nativeFactory->CreateAudioSource(nativeConstraints.get());
  return [[RTCAudioSource alloc] initWithNativeAudioSource:source];
}

- (RTCAudioTrack *)audioTrackWithTrackId:(NSString *)trackId {
  RTCAudioSource *audioSource = [self audioSourceWithConstraints:nil];
  return [self audioTrackWithSource:audioSource trackId:trackId];
}

- (RTCAudioTrack *)audioTrackWithSource:(RTCAudioSource *)source
                                trackId:(NSString *)trackId {
  return [[RTCAudioTrack alloc] initWithFactory:self
                                         source:source
                                        trackId:trackId];
}

- (RTCAVFoundationVideoSource *)avFoundationVideoSourceWithConstraints:
    (nullable RTCMediaConstraints *)constraints {
  return [[RTCAVFoundationVideoSource alloc] initWithFactory:self
                                                 constraints:constraints];
}

- (RTCVideoTrack *)videoTrackWithSource:(RTCVideoSource *)source
                                trackId:(NSString *)trackId {
  return [[RTCVideoTrack alloc] initWithFactory:self
                                         source:source
                                        trackId:trackId];
}

- (RTCMediaStream *)mediaStreamWithStreamId:(NSString *)streamId {
  return [[RTCMediaStream alloc] initWithFactory:self
                                        streamId:streamId];
}

- (RTCPeerConnection *)peerConnectionWithConfiguration:
    (RTCConfiguration *)configuration
                                           constraints:
    (RTCMediaConstraints *)constraints
                                              delegate:
    (nullable id<RTCPeerConnectionDelegate>)delegate {
  return [[RTCPeerConnection alloc] initWithFactory:self
                                      configuration:configuration
                                        constraints:constraints
                                           delegate:delegate];
}

@end
