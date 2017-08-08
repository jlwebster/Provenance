//
//  RLMRealmConfiguration+GroupConfig.m
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "RLMRealmConfiguration+Config.h"
#import "PVAppConstants.h"

@implementation RLMRealmConfiguration (GroupConfig)

+ (void)setRealmConfig
{
    RLMRealmConfiguration *config = [[RLMRealmConfiguration alloc] init];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *iCloudDocumentsURL = [[fileManager URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:@"Documents"];

    if (![fileManager fileExistsAtPath:iCloudDocumentsURL.path isDirectory:nil]) {
        NSError *error;
        [fileManager createDirectoryAtURL:iCloudDocumentsURL withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            NSLog(@"Error creating iCloud Documents folder: %@", error);
        }
    }

    NSURL *realmPath = [iCloudDocumentsURL URLByAppendingPathComponent:@"default.realm"];

    [config setPath:realmPath.path];
    
    // Bump schema version to migrate new PVGame property, isFavorite
    config.schemaVersion = 1;
    config.migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion) {
        // Nothing to do, Realm handles migration automatically when we set an empty migration block
    };
    
    [RLMRealmConfiguration setDefaultConfiguration:config];
}

+ (BOOL)supportsAppGroups
{
    return PVAppGroupId.length && [self appGroupContainer];
}

+ (NSURL *)appGroupContainer
{
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:PVAppGroupId];
}

+ (NSString *)appGroupPath
{
    return [self.appGroupContainer.path stringByAppendingPathComponent:@"Library/Caches/"];
}

@end
