//
//  SJVideoPlayerControlView.m
//  SJVideoPlayerProject
//
//  Created by BlueDancer on 2017/11/29.
//  Copyright © 2017年 SanJiang. All rights reserved.
//

#import "SJVideoPlayerControlView.h"
#import "SJVideoPlayerBottomControlView.h"
#import <Masonry/Masonry.h>
#import "SJVideoPlayer.h"
#import <SJObserverHelper/NSObject+SJObserverHelper.h>
#import "SJVideoPlayerSettings.h"
#import "SJVideoPlayer+ControlAdd.h"
#import "SJVideoPlayerDraggingProgressView.h"
#import "UIView+SJVideoPlayerSetting.h"
#import "SJVideoPlayerLeftControlView.h"

@interface SJVideoPlayerControlView ()<SJVideoPlayerControlDelegate, SJVideoPlayerControlDataSource, SJVideoPlayerBottomControlViewDelegate>

@property (nonatomic, assign) BOOL initialized;

@property (nonatomic, strong, readonly) SJVideoPlayerDraggingProgressView *draggingProgressView;
@property (nonatomic, strong, readonly) SJVideoPlayerLeftControlView *leftControlView;
@property (nonatomic, strong, readonly) SJVideoPlayerBottomControlView *bottomControlView;

@end

@implementation SJVideoPlayerControlView

@synthesize draggingProgressView = _draggingProgressView;
@synthesize leftControlView = _leftControlView;
@synthesize bottomControlView = _bottomControlView;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _controlViewSetupView];
    [self _controlViewLoadDefaultSetting];
    return self;
}

- (void)setVideoPlayer:(SJVideoPlayer *)videoPlayer {
    if ( _videoPlayer == videoPlayer ) return;
    _videoPlayer = videoPlayer;
    _videoPlayer.controlViewDelegate = self;
    _videoPlayer.controlViewDataSource = self;
    [_videoPlayer sj_addObserver:self forKeyPath:@"state"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ( [keyPath isEqualToString:@"state"] ) {
        switch ( _videoPlayer.state ) {
            case SJVideoPlayerPlayState_Prepare: {
            }
                break;
            case SJVideoPlayerPlayState_Paused: {
                self.bottomControlView.playState = NO;
            }
                break;
            case SJVideoPlayerPlayState_Playing: {
                self.bottomControlView.playState = YES;
            }
                break;
            default:
                break;
        }
    }
}


#pragma mark - setup views
- (void)_controlViewSetupView {
    [self addSubview:self.leftControlView];
    [self addSubview:self.bottomControlView];
    [self addSubview:self.draggingProgressView];
    
    [_leftControlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.offset(0);
        make.centerY.offset(0);
    }];
    
    [_bottomControlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.bottom.trailing.offset(0);
    }];
    
    _bottomControlView.transform = CGAffineTransformMakeTranslation(0, _bottomControlView.intrinsicContentSize.height);
    
    
    [_draggingProgressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
    }];
    _draggingProgressView.alpha = 0.001;
}

#pragma mark - 拖拽视图
- (SJVideoPlayerDraggingProgressView *)draggingProgressView {
    if ( _draggingProgressView ) return _draggingProgressView;
    _draggingProgressView = [SJVideoPlayerDraggingProgressView new];
    [_draggingProgressView setPreviewImage:[UIImage imageNamed:@"placeholder"]];
    return _draggingProgressView;
}

#pragma mark - 左侧视图
- (SJVideoPlayerLeftControlView *)leftControlView {
    if ( _leftControlView ) return _leftControlView;
    _leftControlView = [SJVideoPlayerLeftControlView new];
    return _leftControlView;
}

#pragma mark - 底部视图
- (SJVideoPlayerBottomControlView *)bottomControlView {
    if ( _bottomControlView ) return _bottomControlView;
    _bottomControlView = [SJVideoPlayerBottomControlView new];
    _bottomControlView.delegate = self;
    return _bottomControlView;
}

- (void)bottomView:(SJVideoPlayerBottomControlView *)view clickedBtnTag:(SJVideoPlayerBottomViewTag)tag {
    switch ( tag ) {
        case SJVideoPlayerBottomViewTag_Play: {
            [self.videoPlayer play];
        }
            break;
        case SJVideoPlayerBottomViewTag_Pause: {
            [self.videoPlayer pause];
        }
            break;
        case SJVideoPlayerBottomViewTag_Full: {
            [self.videoPlayer rotation];
        }
            break;
        default:
            break;
    }
}

#pragma mark - 播放器代理方法

- (UIView *)controlView {
    return self;
}

- (BOOL)controlLayerDisplayCondition {
    if ( self.bottomControlView.isDragging ) return NO;
    return self.initialized; // 在初始化期间不显示控制层
}

- (void)videoPlayer:(SJVideoPlayer *)videoPlayer controlLayerNeedChangeDisplayState:(BOOL)displayState {
    [UIView animateWithDuration:0.3 animations:^{
        if ( displayState ) {
            _bottomControlView.transform = CGAffineTransformIdentity;
        }
        else {
            _bottomControlView.transform = CGAffineTransformMakeTranslation(0, _bottomControlView.intrinsicContentSize.height);
        }
    }];
}

- (void)videoPlayer:(SJVideoPlayer *)videoPlayer currentTimeStr:(NSString *)currentTimeStr totalTimeStr:(NSString *)totalTimeStr {
    [self.bottomControlView setCurrentTimeStr:currentTimeStr totalTimeStr:totalTimeStr];
}

- (void)videoPlayer:(SJVideoPlayer *)videoPlayer willRotateView:(BOOL)isFull {
    if ( isFull && !videoPlayer.URLAsset.isM3u8 ) {
        self.draggingProgressView.style = SJVideoPlayerDraggingProgressViewStylePreviewProgress;
    }
    else {
        self.draggingProgressView.style = SJVideoPlayerDraggingProgressViewStyleArrowProgress;
    }
    
    // update layout
    self.bottomControlView.fullscreen = isFull;
}

#pragma mark gesture
- (void)horizontalGestureWillBeginDragging:(SJVideoPlayer *)videoPlayer {
    [UIView animateWithDuration:0.25 animations:^{
       self.draggingProgressView.alpha = 1;
    }];
    
    [self.draggingProgressView setCurrentTimeStr:videoPlayer.currentTimeStr totalTimeStr:videoPlayer.totalTimeStr];
    [self videoPlayer:videoPlayer controlLayerNeedChangeDisplayState:NO];
}

- (void)videoPlayer:(SJVideoPlayer *)videoPlayer horizontalGestureDidDrag:(CGFloat)translation {
    self.draggingProgressView.progress += translation;
    [self.draggingProgressView setCurrentTimeStr:[videoPlayer timeStringWithSeconds:self.draggingProgressView.progress * videoPlayer.totalTime]];
    if ( videoPlayer.isFullScreen && !videoPlayer.URLAsset.isM3u8 ) {
        NSTimeInterval secs = self.draggingProgressView.progress * videoPlayer.totalTime;
        __weak typeof(self) _self = self;
        [videoPlayer screenshotWithTime:secs size:CGSizeMake(self.draggingProgressView.frame.size.width * 2, self.draggingProgressView.frame.size.height * 2) completion:^(SJVideoPlayer * _Nonnull videoPlayer, UIImage * _Nullable image, NSError * _Nullable error) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            [self.draggingProgressView setPreviewImage:image];
        }];
    }
}

- (void)horizontalGestureDidEndDragging:(SJVideoPlayer *)videoPlayer {
    [UIView animateWithDuration:0.25 animations:^{
       self.draggingProgressView.alpha = 0.001;
    }];
    
    [self.videoPlayer jumpedToTime:self.draggingProgressView.progress * videoPlayer.totalTime completionHandler:^(BOOL finished) {
        [videoPlayer play];
    }];
}


#pragma mark - load default setting
- (void)_controlViewLoadDefaultSetting {
    
    // load default setting
    __weak typeof(self) _self = self;
    
//    [SJVideoPlayer loadDefaultSettingAndCompletion:^{
//        __strong typeof(_self) self = _self;
//        if ( !self ) return;
//        self.initialized = YES;
//        [self videoPlayer:self.videoPlayer controlLayerNeedChangeDisplayState:YES];
//    }];
    
    // or update
    
    [SJVideoPlayer update:^(SJVideoPlayerSettings * _Nonnull commonSettings) {
        // update common settings
        commonSettings.more_trackColor = [UIColor whiteColor];
        commonSettings.progress_trackColor = [UIColor colorWithWhite:0.4 alpha:1];
        commonSettings.progress_bufferColor = [UIColor whiteColor];
    } completion:^{
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.initialized = YES; // 初始化已完成, 在初始化期间不显示控制层.
        [self videoPlayer:self.videoPlayer controlLayerNeedChangeDisplayState:YES]; // 显示控制层
    }];
}
@end
