//
//  PVAppDelegate.m
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVAppDelegate.h"
#import "PVSettingsModel.h"
#import "PVControllerManager.h"
#import "PVSearchViewController.h"

#if TARGET_OS_TV
#import "PVAppConstants.h"
#endif

@interface PVAppDelegate ()

@property (nonatomic, strong) NSMetadataQuery *query;

@end

@implementation PVAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{

#if TARGET_OS_TV
#else
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *iCloudDocumentsURL = [[fileManager URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:@"Documents"];

    if (iCloudDocumentsURL != nil) {
        if (![fileManager fileExistsAtPath:iCloudDocumentsURL.path isDirectory:nil]) {
            NSError *error;
            [fileManager createDirectoryAtURL:iCloudDocumentsURL withIntermediateDirectories:YES attributes:nil error:&error];
            if (error != nil) {
                NSLog(@"Error creating iCloud Documents folder: %@", error);
            }
        }
    }

    [self syncICloudDocuments];
#endif

    [[UIApplication sharedApplication] setIdleTimerDisabled:[[PVSettingsModel sharedInstance] disableAutoLock]];
#if !TARGET_OS_TV
    if (NSClassFromString(@"UIApplicationShortcutItem")) {
        UIApplicationShortcutItem *shortcut = launchOptions[UIApplicationLaunchOptionsShortcutItemKey];
        if ([[shortcut type] isEqualToString:@"kRecentGameShortcut"])
        {
            self.shortcutItemMD5 = (NSString *)[shortcut userInfo][@"PVGameHash"];
        }
    }
#endif

#if TARGET_OS_TV
	if ([[self.window rootViewController] isKindOfClass:[UITabBarController class]]) {
		UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;

		UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
		[flowLayout setSectionInset:UIEdgeInsetsMake(20, 0, 20, 0)];
		PVSearchViewController *searchViewController = [[PVSearchViewController alloc] initWithCollectionViewLayout:flowLayout];

		UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:searchViewController];
		searchController.searchResultsUpdater = searchViewController;

		UISearchContainerViewController *searchContainerController = [[UISearchContainerViewController alloc] initWithSearchController:searchController];
		[searchContainerController setTitle:@"Search"];

		UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:searchContainerController];

		NSMutableArray *viewControllers = [[tabBarController viewControllers] mutableCopy];
		[viewControllers insertObject:navController atIndex:1];
		[tabBarController setViewControllers:viewControllers];
	}
#endif

	return YES;
}

- (void)syncICloudDocuments {
    self.query = [NSMetadataQuery new];
    [self.query setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDocumentsScope, nil]];
    [self.query setPredicate:[NSPredicate predicateWithFormat:@"%K LIKE '*'", NSMetadataItemFSNameKey]];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(fileListReceived) name:NSMetadataQueryDidFinishGatheringNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(fileListReceived) name:NSMetadataQueryDidUpdateNotification object:nil];
    [self.query startQuery];
}

- (void)fileListReceived {
    NSLog(@"Starting to download iCloud Drive files");

    NSArray *queryResults = self.query.results;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    for (NSMetadataItem *item in queryResults) {
        NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
        NSNumber *isDownloaded = nil;
        [url getResourceValue:&isDownloaded forKey:NSURLUbiquitousItemIsDownloadedKey error:&error];
        if (error != nil) {
            NSLog(@"Error getting resource value %@", error);
            error = nil;
        }
        if (![isDownloaded boolValue]) {
            [fileManager startDownloadingUbiquitousItemAtURL:url error:&error];
            if (error != nil) {
                NSLog(@"Error starting to download %@", error);
                error = nil;
            }
        }
    }
    NSLog(@"Finished downloading iCloud Drive files");
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
#pragma clang diagnostic pop

    if (url && [url isFileURL])
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSString *documentsDirectory;
#if TARGET_OS_TV
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        documentsDirectory = [paths objectAtIndex:0];
#else
        NSURL *iCloudDocumentsURL = [[fileManager URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:@"Documents"];

        documentsDirectory = iCloudDocumentsURL.path;
#endif
        
        NSString *sourcePath = [url path];
        NSString *filename = [sourcePath lastPathComponent];
        NSString *destinationPath = [[documentsDirectory stringByAppendingPathComponent:@"roms"] stringByAppendingPathComponent:filename];

        NSError *error = nil;
        BOOL success = [fileManager moveItemAtPath:sourcePath toPath:destinationPath error:&error];
        if (!success || error)
        {
            NSLog(@"Unable to move file from %@ to %@ because %@", sourcePath, destinationPath, [error localizedDescription]);
        }
    }
#if TARGET_OS_TV
    else if ([components.path isEqualToString:PVGameControllerKey] &&
             [components.queryItems.firstObject.name isEqualToString:PVGameMD5Key])
    {
        self.shortcutItemMD5 = components.queryItems.firstObject.value;
    }
#endif
    
    return YES;
}

#if !TARGET_OS_TV
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(nonnull void (^)(BOOL))completionHandler {
    
    if ([[shortcutItem type] isEqualToString:@"kRecentGameShortcut"])
    {
        self.shortcutItemMD5 = (NSString *)[shortcutItem userInfo][@"PVGameHash"];
    }
    
    completionHandler(YES);
}
#endif

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{

}

@end
