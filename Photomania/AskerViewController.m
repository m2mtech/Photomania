//
//  AskerViewController.m
//  Kitchen Sink
//
//  Created by Martin Mandl on 08.08.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import "AskerViewController.h"

@interface AskerViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UITextField *answerTextField;

@end

@implementation AskerViewController

@synthesize questionLabel = _questionLabel;
@synthesize answerTextField = _answerTextField;
@synthesize question = _question;
@synthesize answer = _answer;
@synthesize delegate = _delegate;

- (void)setQuestion:(NSString *)question
{
    if (question == _question) return;
    _question = question;
}

- (void)setAnswer:(NSString *)answer
{
    _answer = answer;
    self.answerTextField.placeholder = answer;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.answer = textField.text;
    if (![textField.text length]) {
        [[self presentingViewController] dismissModalViewControllerAnimated:YES];
    } else {
        [self.delegate askerViewController:self 
                            didAskQuestion:self.question 
                              andGotAnswer:self.answer];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([textField.text length]) {
        [textField resignFirstResponder];
        return YES;
    } else {
        return NO;
    }    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.questionLabel.text = self.question;
    self.answerTextField.placeholder = self.answer;
    self.answerTextField.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.answerTextField becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)viewDidUnload {
    [self setQuestionLabel:nil];
    [self setAnswerTextField:nil];
    [super viewDidUnload];
}
@end
