//
//  ViewController.m
//  Browser
//
//  Created by Steven Troughton-Smith on 20/09/2015.
//  Improved by Jip van Akker on 14/10/2015
//  Copyright © 2015 High Caffeine Content. All rights reserved.
//

#import "ViewController.h"
#import <GameController/GameController.h>

typedef struct _Input
{
    CGFloat x;
    CGFloat y;
} Input;


@interface ViewController ()
{
    UIImageView *cursorView;
    UIActivityIndicatorView *loadingSpinner;
    Input input;
    NSString *requestURL;
    NSString *previousURL;
}

@property id webview;
@property (strong) CADisplayLink *link;
@property (strong, nonatomic) GCController *controller;
@property BOOL cursorMode;
@property BOOL displayedHintsOnLaunch;
@property BOOL scrollViewAllowBounces;
@property CGPoint lastTouchLocation;
@property NSUInteger textFontSize;

@end

@implementation ViewController {
    UITapGestureRecognizer *touchSurfaceDoubleTapRecognizer;
    UITapGestureRecognizer *playPauseOrMenuDoubleTapRecognizer;
}
-(void) webViewDidStartLoad:(id)webView {
    //[self.view bringSubviewToFront:loadingSpinner];
    if (![previousURL isEqualToString:requestURL]) {
        [loadingSpinner startAnimating];
    }
    previousURL = requestURL;
}
-(void) webViewDidFinishLoad:(id)webView {
    [loadingSpinner stopAnimating];
    //[self.view bringSubviewToFront:loadingSpinner];
    NSString *theTitle=[webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    NSURLRequest *request = [webView request];
    NSString *currentURL = request.URL.absoluteString;
    NSArray *toSaveItem = [NSArray arrayWithObjects:currentURL, theTitle, nil];
    NSMutableArray *historyArray = [NSMutableArray arrayWithObjects:toSaveItem, nil];
    if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"] != nil) {
        NSMutableArray *savedArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"] mutableCopy];
        if ([savedArray count] > 0) {
            if ([savedArray[0][0] isEqualToString: currentURL]) {
                [historyArray removeObjectAtIndex:0];
            }
        }
        [historyArray addObjectsFromArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"]];
    }
    while ([historyArray count] > 100) {
        [historyArray removeLastObject];
    }
    NSArray *toStoreArray = historyArray;
    [[NSUserDefaults standardUserDefaults] setObject:toStoreArray forKey:@"HISTORY"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    loadingSpinner.center = CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), CGRectGetMidY([UIScreen mainScreen].bounds));
    [self webViewDidAppear];
    _displayedHintsOnLaunch = YES;
}
-(void)webViewDidAppear {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"savedURLtoReopen"] != nil) {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"savedURLtoReopen"]]]];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"savedURLtoReopen"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else if ([self.webview request] == nil) {
        //[self requestURLorSearchInput];
        [self loadHomePage];
    }
//    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DontShowHintsOnLaunch"] && !_displayedHintsOnLaunch) {
//        [self showHintsAlert];
//    }
}
-(void)loadHomePage {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"homepage"] != nil) {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"homepage"]]]];
    }
    else {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString: @"https://dashcontrol.envoy.com/display/show"]]];
    }
}
-(void)initWebView {
    if (@available(tvOS 11.0, *)) {
        self.view.insetsLayoutMarginsFromSafeArea = false;
        self.additionalSafeAreaInsets = UIEdgeInsetsZero;
    }
    self.webview = [[NSClassFromString(@"UIWebView") alloc] init];
    [self.webview setTranslatesAutoresizingMaskIntoConstraints:false];
    [self.webview setClipsToBounds:false];
    
    //[self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]]];
    
    [self.view addSubview: self.webview];
    [self.webview setFrame:self.view.frame];
    [self.webview setDelegate:self];
    [self.webview setLayoutMargins:UIEdgeInsetsZero];
    UIScrollView *scrollView = [self.webview scrollView];
    [scrollView setLayoutMargins:UIEdgeInsetsZero];
    if (@available(tvOS 11.0, *)) {
        scrollView.insetsLayoutMarginsFromSafeArea = false;
    }
    scrollView.contentOffset = CGPointZero;
    scrollView.contentInset = UIEdgeInsetsZero;
    scrollView.frame = self.view.frame;
    scrollView.clipsToBounds = NO;
    [scrollView setNeedsLayout];
    [scrollView layoutIfNeeded];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DisableOffsetCorrection"]) {
        CGPoint point = CGPointMake(60, 90);
        scrollView.contentInset = UIEdgeInsetsMake(-point.x, -point.y, -point.x, -point.y);
        [self offsetCorrection:YES];
    } else {
        [self offsetCorrection:NO];
    }
    scrollView.bounces = _scrollViewAllowBounces;
    scrollView.panGestureRecognizer.allowedTouchTypes = @[ @(UITouchTypeIndirect) ];
    scrollView.scrollEnabled = NO;
    
    [self.webview setUserInteractionEnabled:NO];
}
-(void)offsetCorrection:(bool)yes {
    UIScrollView *scrollView = [self.webview scrollView];
    if (yes) {
        CGPoint point = CGPointMake(60, 90);
        scrollView.contentInset = UIEdgeInsetsMake(-point.x, -point.y, -point.x, -point.y);
    } else {
        scrollView.contentInset = UIEdgeInsetsZero;
    }
}
-(void)viewDidLoad {
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.definesPresentationContext = YES;
    [self initWebView];
    _scrollViewAllowBounces = YES;
    [super viewDidLoad];
    
    loadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    loadingSpinner.center = CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), CGRectGetMidY([UIScreen mainScreen].bounds));
    loadingSpinner.tintColor = [UIColor blackColor];
    loadingSpinner.hidesWhenStopped = true;
    //[loadingSpinner startAnimating];
    [self.view addSubview:loadingSpinner];
    [self.view bringSubviewToFront:loadingSpinner];
    self.textFontSize = 100;
}
- (BOOL)webView:(id)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    requestURL = request.URL.absoluteString;
    return YES;
}
- (void)webView:(id)webView didFailLoadWithError:(NSError *)error {
    [loadingSpinner stopAnimating];
    if (![[NSString stringWithFormat:@"%lid", (long)error.code] containsString:@"999"] && ![[NSString stringWithFormat:@"%lid", (long)error.code] containsString:@"204"]) {
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:@"Could Not Load Webpage"
                                              message:[error localizedDescription]
                                              preferredStyle:UIAlertControllerStyleAlert];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

@end
