//
//  ViewController.m
//  SecureCommunicator
//
//  Created by Abdul Al-Shawa on 2016-03-26.
//  Copyright © 2016 Abdul Al-Shawa. All rights reserved.
//

#import "ViewController.h"

static vDSP_Length const FFTViewControllerFFTWindowSize = 4096;
double const SAMPLE_RATE = 44100.0;

typedef NS_ENUM(NSUInteger, GeneratorType)
{
	GeneratorTypeSine,
	GeneratorTypeSquare,
	GeneratorTypeTriangle,
	GeneratorTypeSawtooth,
	GeneratorTypeNoise,
};

typedef NS_ENUM(NSUInteger, SystemMode)
{
	SystemModeExploring,
	SystemModeTransmitting
};

@interface ViewController () <EZOutputDataSource, EZOutputDelegate>

@property (assign) GeneratorType toneShape;
@property (nonatomic) double toneAmplitude;
@property (nonatomic) double toneFrequency;
@property (nonatomic) double sampleRate;
@property (nonatomic) double step;
@property (nonatomic) double theta;

@property (nonatomic) SystemMode mode;
@property (nonatomic) NSUInteger selectedIdx;
@property (nonatomic) BOOL transmitting;

@end


@implementation ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	// Setup the AVAudioSession
	AVAudioSession *session = [AVAudioSession sharedInstance];
	
	NSError *error;
	[session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
	if (error){
		NSLog(@"Error setting up audio session category: %@", error.localizedDescription);
	}
	
	[session setActive:YES error:&error];
	if (error) {
		NSLog(@"Error setting up audio session active: %@", error.localizedDescription);
	}
	
	// Setup time domain audio plot
	self.audioPlotTime.plotType = EZPlotTypeBuffer;
	self.maxFrequencyLabel.numberOfLines = 0;
	
	// Setup frequency domain audio plot
	self.audioPlotFreq.shouldFill = YES;
	self.audioPlotFreq.plotType = EZPlotTypeBuffer;
	self.audioPlotFreq.shouldCenterYAxis = NO;
//	self.audioPlotFreq.color = [UIColor redColor];
	
	// Create an instance of the microphone and tell it to use this view controller instance as the delegate
	self.microphone = [EZMicrophone microphoneWithDelegate:self];
	
	// Create an instance of the EZAudioFFTRolling to keep a history of the incoming audio data and calculate the FFT.
	self.fft = [EZAudioFFTRolling fftWithWindowSize:FFTViewControllerFFTWindowSize
										 sampleRate:self.microphone.audioStreamBasicDescription.mSampleRate
										   delegate:self];
	
	// Start fetching audio from the mic
	[self.microphone startFetchingAudio];
	
	
	// Audio Output State - -
	AudioStreamBasicDescription inputFormat = [EZAudioUtilities monoFloatFormatWithSampleRate:SAMPLE_RATE];
	self.output = [EZOutput outputWithDataSource:self inputFormat:inputFormat];
	
	[self.output setDelegate:self];
	
	self.toneFrequency = 2000.0;
	self.sampleRate = inputFormat.mSampleRate;
	self.toneAmplitude = 0.5;
	self.toneShape = GeneratorTypeSine;
	
	// UI Configuration
	self.mode = SystemModeTransmitting;
	
	self.amplitudeSlider.value = self.toneAmplitude / 10;
	[self.segmentedControl setSelectedSegmentIndex:1];
	[self.segmentedControl setTintColor:[UIColor whiteColor]];
	
	[self.segmentedControl addTarget:self action:@selector(onToggleSegmentedControl:) forControlEvents:UIControlEventValueChanged];
	[self.emotion1Btn addTarget:self action:@selector(toggleToneBtnTouchDown:) forControlEvents:UIControlEventTouchDown];
	[self.emotion2Btn addTarget:self action:@selector(toggleToneBtnTouchDown:) forControlEvents:UIControlEventTouchDown];
	[self.emotion3Btn addTarget:self action:@selector(toggleToneBtnTouchDown:) forControlEvents:UIControlEventTouchDown];
	[self.emotion4Btn addTarget:self action:@selector(toggleToneBtnTouchDown:) forControlEvents:UIControlEventTouchDown];
	
	[self.emotion1Btn addTarget:self action:@selector(toggleToneBtnTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
	[self.emotion2Btn addTarget:self action:@selector(toggleToneBtnTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
	[self.emotion3Btn addTarget:self action:@selector(toggleToneBtnTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
	[self.emotion4Btn addTarget:self action:@selector(toggleToneBtnTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
}

#pragma mark - Status Bar
- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

#pragma mark - EZMicrophoneDelegate
-(void)    microphone:(EZMicrophone *)microphone
	 hasAudioReceived:(float **)buffer
	   withBufferSize:(UInt32)bufferSize
 withNumberOfChannels:(UInt32)numberOfChannels
{
	// Calculate the FFT, will trigger EZAudioFFTDelegate
	[self.fft computeFFTWithBuffer:buffer[0] withBufferSize:bufferSize];
	
	__weak typeof (self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf.audioPlotTime updateBuffer:buffer[0]
							  withBufferSize:bufferSize];
	});
}

#pragma mark - EZAudioFFTDelegate
- (void)        fft:(EZAudioFFT *)fft
 updatedWithFFTData:(float *)fftData
		 bufferSize:(vDSP_Length)bufferSize
{
	const float errorMargin = 0.05f;
	
	float maxFrequency = [fft maxFrequency];
	NSString *noteName = [EZAudioUtilities noteNameStringForFrequency:maxFrequency includeOctave:YES];
	
	if (self.mode == SystemModeExploring) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (maxFrequency < 2000 * (1 + errorMargin) && maxFrequency > 2000 * (1 - errorMargin)) {
				self.emotion1Btn.alpha = 1.f;
			} else if (maxFrequency < 1750 * (1 + errorMargin) && maxFrequency > 1750 * (1 - errorMargin)) {
				self.emotion2Btn.alpha = 1.f;
			} else if (maxFrequency < 1500 * (1 + errorMargin) && maxFrequency > 1500 * (1 - errorMargin)) {
				self.emotion3Btn.alpha = 1.f;
			} else if (maxFrequency < 1000 * (1 + errorMargin) && maxFrequency > 1000 * (1 - errorMargin)) {
				self.emotion4Btn.alpha = 1.f;
			} else {
				self.emotion1Btn.alpha = 0.5f;
				self.emotion2Btn.alpha = 0.5f;
				self.emotion3Btn.alpha = 0.5f;
				self.emotion4Btn.alpha = 0.5f;
			}
		});
	}
	
	__weak typeof (self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		weakSelf.maxFrequencyLabel.text = [NSString stringWithFormat:@"%@\n %.2f Hz", noteName, maxFrequency];
		[weakSelf.audioPlotFreq updateBuffer:fftData withBufferSize:(UInt32)bufferSize];
	});
}

#pragma mark - User Interface
- (void)toggleToneBtnTouchUp:(UIButton *)sender
{
	if ([self.output isPlaying] && self.mode == SystemModeTransmitting) {
		[self.output stopPlayback];
		self.transmitting = NO;
	}
}

- (void)toggleToneBtnTouchDown:(UIButton *)sender
{
	if (![self.output isPlaying] && self.mode == SystemModeTransmitting) {
		
		self.selectedIdx = sender.tag;
		
		self.toneFrequency = 2000 - (250 * self.selectedIdx);
		
		[self.output startPlayback];
		self.transmitting = YES;
	}
}

- (void)onToggleSegmentedControl:(UISegmentedControl *)sender
{
	NSUInteger selectedSegmentIdx = sender.selectedSegmentIndex;
	self.mode = selectedSegmentIdx;
	
	switch (self.mode) {
		case SystemModeExploring:
		{
			[self.output stopPlayback];
			
			self.emotion1Btn.userInteractionEnabled = NO;
			self.emotion2Btn.userInteractionEnabled = NO;
			self.emotion3Btn.userInteractionEnabled = NO;
			self.emotion4Btn.userInteractionEnabled = NO;
			
			self.emotion1Btn.alpha = 0.5f;
			self.emotion2Btn.alpha = 0.5f;
			self.emotion3Btn.alpha = 0.5f;
			self.emotion4Btn.alpha = 0.5f;
			
			break;
		}
		case SystemModeTransmitting:
		{
			self.emotion1Btn.userInteractionEnabled = YES;
			self.emotion2Btn.userInteractionEnabled = YES;
			self.emotion3Btn.userInteractionEnabled = YES;
			self.emotion4Btn.userInteractionEnabled = YES;
			
			self.emotion1Btn.alpha = 1.f;
			self.emotion2Btn.alpha = 1.f;
			self.emotion3Btn.alpha = 1.f;
			self.emotion4Btn.alpha = 1.f;
			
			if(self.transmitting) {
				[self.output startPlayback];
			}
			break;
		}
	}
}

- (IBAction)onSliderValueChange:(UISlider *)sender {
	
	self.toneAmplitude = sender.value;
	
}

#pragma mark - EZOutputDataSource
- (OSStatus)        output:(EZOutput *)output
 shouldFillAudioBufferList:(AudioBufferList *)audioBufferList
		withNumberOfFrames:(UInt32)frames
				 timestamp:(const AudioTimeStamp *)timestamp
{
	Float32 *buffer = (Float32 *)audioBufferList->mBuffers[0].mData;
	size_t bufferByteSize = (size_t)audioBufferList->mBuffers[0].mDataByteSize;
	double theta = self.theta;
	double frequency = self.toneFrequency;
	double thetaIncrement = 2.0 * M_PI * frequency / SAMPLE_RATE;
	if (self.toneShape == GeneratorTypeSine)
	{
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			buffer[frame] = self.toneAmplitude * sin(theta);
			theta += thetaIncrement;
			if (theta > 2.0 * M_PI)
			{
				theta -= 2.0 * M_PI;
			}
		}
		self.theta = theta;
	}
	else if (self.toneShape == GeneratorTypeNoise)
	{
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			buffer[frame] = self.toneAmplitude * ((float)rand()/RAND_MAX) * 2.0f - 1.0f;
		}
	}
	else if (self.toneShape == GeneratorTypeSquare)
	{
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			buffer[frame] = self.toneAmplitude * [EZAudioUtilities SGN:theta];
			theta += thetaIncrement;
			if (theta > 2.0 * M_PI)
			{
				theta -= 4.0 * M_PI;
			}
		}
		self.theta = theta;
	}
	else if (self.toneShape == GeneratorTypeTriangle)
	{
		double samplesPerWavelength = SAMPLE_RATE / self.toneFrequency;
		double ampStep = 2.0 / samplesPerWavelength;
		double step = self.step;
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			if (step > 1.0)
			{
				step = 1.0;
				ampStep = -ampStep;
			}
			else if (step < -1.0)
			{
				step = -1.0;
				ampStep = -ampStep;
			}
			step += ampStep;
			buffer[frame] = self.toneAmplitude * step;
		}
		self.step = step;
	}
	else if (self.toneShape == GeneratorTypeSawtooth)
	{
		double samplesPerWavelength = SAMPLE_RATE / self.toneFrequency;
		double ampStep = 1.0 / samplesPerWavelength;
		double step = self.step;
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			if (step > 1.0)
			{
				step = -1.0;
			}
			step += ampStep;
			buffer[frame] = self.toneAmplitude * step;
		}
		self.step = step;
	}
	else
	{
		memset(buffer, 0, bufferByteSize);
	}
	return noErr;
}

@end
