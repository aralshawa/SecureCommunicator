//
//  ViewController.h
//  SecureCommunicator
//
//  Created by Abdul Al-Shawa on 2016-03-26.
//  Copyright © 2016 Abdul Al-Shawa. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <EZAudio/EZAudio.h>


@interface ViewController : UIViewController <EZMicrophoneDelegate, EZAudioFFTDelegate>

@property (nonatomic,weak) IBOutlet EZAudioPlot *audioPlotFreq;
@property (nonatomic,weak) IBOutlet EZAudioPlot *audioPlotTime;

// A label used to display the maximum frequency (i.e. the frequency with the
// highest energy) calculated from the FFT.
@property (nonatomic, weak) IBOutlet UILabel *maxFrequencyLabel;

// The microphone used to get input.
@property (nonatomic,strong) EZMicrophone *microphone;

// Used to calculate a rolling FFT of the incoming audio data.
@property (nonatomic, strong) EZAudioFFTRolling *fft;

// Audio Output
@property (nonatomic, strong) EZOutput *output;

@end

