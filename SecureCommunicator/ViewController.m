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

@interface ViewController () <EZOutputDataSource, EZOutputDelegate>

	@property (assign) GeneratorType type;
	@property (nonatomic) double amplitude;
	@property (nonatomic) double frequency;
	@property (nonatomic) double sampleRate;
	@property (nonatomic) double step;
	@property (nonatomic) double theta;

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
	
	self.frequency = 200.0;
	self.sampleRate = inputFormat.mSampleRate;
	self.amplitude = 0.80;
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
	float maxFrequency = [fft maxFrequency];
	NSString *noteName = [EZAudioUtilities noteNameStringForFrequency:maxFrequency includeOctave:YES];
	
	__weak typeof (self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		weakSelf.maxFrequencyLabel.text = [NSString stringWithFormat:@"Highest Note: %@,\nFrequency: %.2f", noteName, maxFrequency];
		[weakSelf.audioPlotFreq updateBuffer:fftData withBufferSize:(UInt32)bufferSize];
	});
}

#pragma mark - Generate Tone
- (IBAction)toggleToneBtnTouchUp:(UIButton *)sender {
	if (![self.output isPlaying]) {
		[self.output startPlayback];
	} else {
		[self.output stopPlayback];
	}
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
	double frequency = self.frequency;
	double thetaIncrement = 2.0 * M_PI * frequency / SAMPLE_RATE;
	if (self.type == GeneratorTypeSine)
	{
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			buffer[frame] = self.amplitude * sin(theta);
			theta += thetaIncrement;
			if (theta > 2.0 * M_PI)
			{
				theta -= 2.0 * M_PI;
			}
		}
		self.theta = theta;
	}
	else if (self.type == GeneratorTypeNoise)
	{
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			buffer[frame] = self.amplitude * ((float)rand()/RAND_MAX) * 2.0f - 1.0f;
		}
	}
	else if (self.type == GeneratorTypeSquare)
	{
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			buffer[frame] = self.amplitude * [EZAudioUtilities SGN:theta];
			theta += thetaIncrement;
			if (theta > 2.0 * M_PI)
			{
				theta -= 4.0 * M_PI;
			}
		}
		self.theta = theta;
	}
	else if (self.type == GeneratorTypeTriangle)
	{
		double samplesPerWavelength = SAMPLE_RATE / self.frequency;
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
			buffer[frame] = self.amplitude * step;
		}
		self.step = step;
	}
	else if (self.type == GeneratorTypeSawtooth)
	{
		double samplesPerWavelength = SAMPLE_RATE / self.frequency;
		double ampStep = 1.0 / samplesPerWavelength;
		double step = self.step;
		for (UInt32 frame = 0; frame < frames; frame++)
		{
			if (step > 1.0)
			{
				step = -1.0;
			}
			step += ampStep;
			buffer[frame] = self.amplitude * step;
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
