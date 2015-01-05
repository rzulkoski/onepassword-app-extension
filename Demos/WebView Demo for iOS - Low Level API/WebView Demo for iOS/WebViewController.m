//
//  WebViewController.m
//  1Password Extension Demo
//
//  Created by Dave Teare on 2014-07-19.
//  Copyright (c) 2014 AgileBits. All rights reserved.
//

#import "WebViewController.h"

#import "OnePasswordExtension.h"

@interface WebViewController() <UISearchBarDelegate, WKNavigationDelegate, UIActivityItemSource>

@property (weak, nonatomic) IBOutlet UIButton *onepasswordFillButton;
@property (weak, nonatomic) IBOutlet UIView *webViewContainer;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) WKWebView *webView;
@property (nonatomic) NSExtensionItem *onePasswordExtensionItem;

@end

@implementation WebViewController

#pragma mark - Life Cycle

- (void)viewDidLoad {
	[self.onepasswordFillButton setHidden:![[OnePasswordExtension sharedExtension] isAppExtensionAvailable]];

	WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
	self.webView = [[WKWebView alloc] initWithFrame:self.webViewContainer.bounds configuration:configuration];
	self.webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	self.webView.navigationDelegate = self;
	[self.webViewContainer addSubview:self.webView];

	NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"welcome" ofType:@"html"];
	NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
	[self.webView loadHTMLString:htmlString baseURL:nil];
}

#pragma mark - Actions

- (IBAction)fillUsing1Password:(id)sender {
	OnePasswordExtension *onePasswordExtension = [OnePasswordExtension sharedExtension];

	// Create the 1Password extension item.
	__weak typeof (self) miniMe = self;
	[onePasswordExtension createExtensionItemForWebView:self.webView completion:^(NSExtensionItem *extensionItem, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			// Initialize the 1Password extension item
			self.onePasswordExtensionItem = extensionItem;

			NSArray *activityItems = @[ self ]; // Add as many custom activity items as you please

			// Setting up the activity view controller
			UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems  applicationActivities:nil];

			__strong typeof(self) strongMe = miniMe;

			if ([sender isKindOfClass:[UIBarButtonItem class]]) {
				strongMe.popoverPresentationController.barButtonItem = sender;
			}
			else if ([sender isKindOfClass:[UIView class]]) {
				strongMe.popoverPresentationController.sourceView = [sender superview];
				strongMe.popoverPresentationController.sourceRect = [sender frame];
			}

			activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError)
			{
				// Executed when the 1Password Extension is called
				if ([onePasswordExtension isOnePasswordExtensionActivityType:activityType]) {
					if (returnedItems.count > 0) {
						[onePasswordExtension fillReturnedItems:returnedItems intoWebView:strongMe.webView completion:^(BOOL success, NSError *error) {
							if (!success) {
								NSLog(@"Failed to fill login in webview: <%@>", error);
							}
						}];
					}
				}
				else {
					// Code for other custom activity types
				}
			};

			[strongMe presentViewController:activityViewController animated:YES completion:nil];
		});
	}];
}

- (IBAction)goBack:(id)sender {
	WKNavigation *navigation = [self.webView goBack];

	if (!navigation) {
		NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"welcome" ofType:@"html"];
		NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
		[self.webView loadHTMLString:htmlString baseURL:nil];

	}
}

- (IBAction)goForward:(id)sender {
	[self.webView goForward];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[self loadURLString:searchBar.text];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[self loadURLString:searchBar.text];
}

- (void)handleSearch:(UISearchBar *)searchBar {
	[self loadURLString:searchBar.text];
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar {
	[self loadURLString:searchBar.text];
	[searchBar resignFirstResponder];
}

#pragma mark - Convenience Methods

- (void)loadURLString:(NSString *)URLString {
	if (![URLString hasPrefix:@"http"]) {
		URLString = [NSString stringWithFormat:@"https://%@", URLString];
	}
	
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:URLString]];
	[self.webView loadRequest:request];
	
	self.searchBar.text = URLString;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
	self.searchBar.text = webView.URL.absoluteString;

	if ([self.searchBar.text isEqualToString:@"about:blank"]) {
		self.searchBar.text = @"";
	}
}

#pragma mark - UIActivityItemSource Protocol

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController {
	// Return the current URL as a placeholder
	return self.webView.URL;
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
	if ([[OnePasswordExtension sharedExtension] isOnePasswordExtensionActivityType:activityType]) {
		// Return the 1Password extension item
		return self.onePasswordExtensionItem;
	}
	else {
		// Return the current URL
		return self.webView.URL;
	}
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(NSString *)activityType {
	// Because of our UTI declaration, this UTI now satisfies both the 1Password Extension and the usual NSURL for Share extensions.
	return @"org.appextension.fill-webview-action";
}

@end