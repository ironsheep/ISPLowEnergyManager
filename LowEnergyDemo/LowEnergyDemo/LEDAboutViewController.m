//
//  LEDAboutViewController.m
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 08/23/14.
//  Copyright (c) 2014 Iron Sheep Productions, LLC. All rights reserved.
//

#import "LEDAboutViewController.h"

#pragma mark CLASS LEDAboutViewController PRIVATE Interface

@interface LEDAboutViewController () {

}

//#pragma mark --> PRIVATE Properties

#pragma mark --> PRIVATE Interface-builder Outlet Properties

@property (weak, nonatomic) IBOutlet UILabel *lblAppVersion;

//#pragma mark --> PRIVATE Interface-builder Action Methods

//#pragma mark --> PRIVATE (Utility) Methods

@end


#pragma mark - CLASS LEDAboutViewController Implemention

@implementation LEDAboutViewController {

}

//#pragma mark --> PUBLIC Property Synthesis Overrides

//#pragma mark --> PRIVATE Property Synthesis Overrides

//#pragma mark --> CLASS (Static) Methods

//#pragma mark --> PUBLIC Property Overrides

#pragma mark --> PUBLIC Instance Methods

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Custom initialization
    }
    return self;
}

//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
//{
//    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//    if (self) {
//        // Custom initialization
//    }
//    return self;
//}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    NSString *strAppName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    NSString *strVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

    self.lblAppVersion.text = [NSString stringWithFormat:@"%@ v%@", strAppName, strVersion];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // Do any final setup prior to the view appearing/reappearing.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//#pragma mark --> Interface-builder Action Methods

//#pragma mark --> PRIVATE Property Overrides

//#pragma mark --> PRIVATE (Utility) Methods

@end
