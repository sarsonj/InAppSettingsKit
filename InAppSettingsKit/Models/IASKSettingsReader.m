//
//	IASKSettingsReader.m
//	http://www.inappsettingskit.com
//
//	Copyright (c) 2009:
//	Luc Vandal, Edovia Inc., http://www.edovia.com
//	Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//	All rights reserved.
//
//	It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz,
//	as the original authors of this code. You can give credit in a blog post, a tweet or on
//	a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//	This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import <Foundation/Foundation.h>
#import "IASKSettingsReader.h"
#import "IASKSpecifier.h"
#import "UIDevice+MKAdditions.h"


#pragma mark -
@interface IASKSettingsReader () {
}
@end

@interface IASKSettingsReader ()
- (BOOL)supportsHw:(NSString*)hwSpec;

@end

@implementation IASKSettingsReader

- (id) initWithSettingsFileNamed:(NSString*) fileName
               applicationBundle:(NSBundle*) bundle {
    self = [super init];
    if (self) {
        _applicationBundle = [bundle retain];
        
        NSString* plistFilePath = [self locateSettingsFile: fileName];
        _settingsDictionary = [[NSDictionary dictionaryWithContentsOfFile:plistFilePath] retain];
        
        //store the bundle which we'll need later for getting localizations
        NSString* settingsBundlePath = [plistFilePath stringByDeletingLastPathComponent];
        _settingsBundle = [[NSBundle bundleWithPath:settingsBundlePath] retain];
        
        // Look for localization file
        self.localizationTable = [_settingsDictionary objectForKey:@"StringsTable"];
        if (!self.localizationTable)
        {
            // Look for localization file using filename
            self.localizationTable = [[[[plistFilePath stringByDeletingPathExtension] // removes '.plist'
                                        stringByDeletingPathExtension] // removes potential '.inApp'
                                       lastPathComponent] // strip absolute path
                                      stringByReplacingOccurrencesOfString:[self platformSuffixForInterfaceIdiom:UI_USER_INTERFACE_IDIOM()] withString:@""]; // removes potential '~device' (~ipad, ~iphone)
            if([self.settingsBundle pathForResource:self.localizationTable ofType:@"strings"] == nil){
                // Could not find the specified localization: use default
                self.localizationTable = @"Root";
            }
        }
        
        if (self.settingsDictionary) {
            [self _reinterpretBundle:self.settingsDictionary];
        }
    }
    return self;
}

- (id)initWithFile:(NSString*)file {
    return [self initWithSettingsFileNamed:file applicationBundle:[NSBundle mainBundle]];
}
/*
=======
	if ((self=[super init])) {


		self.path = [self locateSettingsFile: file];
		[self setSettingsBundle:[NSDictionary dictionaryWithContentsOfFile:self.path]];
		self.bundlePath = [self.path stringByDeletingLastPathComponent];
		_bundle = [[NSBundle bundleWithPath:[self bundlePath]] retain];
		
		// Look for localization file
		self.localizationTable = (self.settingsBundle)[@"StringsTable"];
		if (!self.localizationTable)
		{
			// Look for localization file using filename
			self.localizationTable = [[[[self.path stringByDeletingPathExtension] // removes '.plist'
										stringByDeletingPathExtension] // removes potential '.inApp'
									   lastPathComponent] // strip absolute path
									  stringByReplacingOccurrencesOfString:[self platformSuffix] withString:@""]; // removes potential '~device' (~ipad, ~iphone)
			if([_bundle pathForResource:self.localizationTable ofType:@"strings"] == nil){
				// Could not find the specified localization: use default
				self.localizationTable = @"Root";
			}
		}
>>>>>>> oldversion
*/
- (id)init {
    return [self initWithFile:@"Root"];
}

- (void)dealloc {
    [_localizationTable release], _localizationTable = nil;
    [_settingsDictionary release], _settingsDictionary = nil;
    [_dataSource release], _dataSource = nil;
    [_settingsBundle release], _settingsBundle = nil;
    [_hiddenKeys release], _hiddenKeys = nil;
    
    [super dealloc];
}


- (void)setHiddenKeys:(NSSet *)anHiddenKeys {
    if (_hiddenKeys != anHiddenKeys) {
        id old = _hiddenKeys;
        _hiddenKeys = [anHiddenKeys retain];
        [old release];
        
        if (self.settingsDictionary) {
            [self _reinterpretBundle:self.settingsDictionary];
        }
    }
}

- (BOOL)supportsHw:(NSString*)hwSpec {
    #if TARGET_IPHONE_SIMULATOR
    return YES;
    #endif
    int enabled = B_UNKNOWN;
    BOOL or =  [hwSpec rangeOfString:@"or"].location != NSNotFound;
    if (hwSpec != nil) {
        // only when camera available
        if ([hwSpec rangeOfString:@"camera"].location != NSNotFound) {
            enabled = [[UIDevice currentDevice] cameraAvailable];
        }
        // only on iPhone
        if ((enabled || or) && [hwSpec rangeOfString:@"iPhone"].location != NSNotFound) {
            if (or && enabled != B_UNKNOWN) {

            } else {
                enabled = !ISIPAD;
            }
        }
        // only on iOS5
        if ((enabled || or) && [hwSpec rangeOfString:@"iiOS5"].location != NSNotFound) {
            if (or && enabled != B_UNKNOWN) {
            } else {
                enabled = [[UIScreen mainScreen] respondsToSelector:@selector(setBrightness:)];
            }
        }
    }
    return enabled;
}

- (void)_reinterpretBundle:(NSDictionary*)settingsBundle {
	NSArray *preferenceSpecifiers	= settingsBundle[kIASKPreferenceSpecifiers];
	NSInteger sectionCount			= -1;
	NSMutableArray *dataSource		= [[[NSMutableArray alloc] init] autorelease];
    BOOL skipSection = NO;
	for (NSDictionary *specifier in preferenceSpecifiers) {
		if ([(NSString*)specifier[kIASKType] isEqualToString:kIASKPSGroupSpecifier] ) {
            skipSection = ![self supportsHw:specifier[kIASKHWSpec]];
            if (!skipSection) {
                NSMutableArray *newArray = [[NSMutableArray alloc] init];
                [newArray addObject:specifier];
                [dataSource addObject:newArray];
                [newArray release];
                sectionCount++;
            }
		}
		else {
            if (!skipSection) {
                BOOL skipSItem = ![self supportsHw:specifier[kIASKHWSpec]];
                if (!skipSItem) {
                    IASKSpecifier *newSpecifier = [[IASKSpecifier alloc] initWithSpecifier:specifier];

                    if (sectionCount == -1) {
                        NSMutableArray *newArray = [[NSMutableArray alloc] init];
                        [dataSource addObject:newArray];
                        [newArray release];
                        sectionCount++;
                    }

                    [(NSMutableArray*)dataSource[sectionCount] addObject:newSpecifier];
                    [newSpecifier release];
                }
            }
		}
	}
	[self setDataSource:dataSource];
/*=======

- (void)_reinterpretBundle:(NSDictionary*)settingsBundle {
    NSArray *preferenceSpecifiers	= [settingsBundle objectForKey:kIASKPreferenceSpecifiers];
    NSInteger sectionCount			= -1;
    NSMutableArray *dataSource		= [[[NSMutableArray alloc] init] autorelease];
    
    for (NSDictionary *specifier in preferenceSpecifiers) {
        if ([self.hiddenKeys containsObject:[specifier objectForKey:kIASKKey]]) {
            continue;
        }
        if ([(NSString*)[specifier objectForKey:kIASKType] isEqualToString:kIASKPSGroupSpecifier]) {
            NSMutableArray *newArray = [[NSMutableArray alloc] init];
            
            [newArray addObject:specifier];
            [dataSource addObject:newArray];
            [newArray release];
            sectionCount++;
        }
        else {
            if (sectionCount == -1) {
                NSMutableArray *newArray = [[NSMutableArray alloc] init];
                [dataSource addObject:newArray];
                [newArray release];
                sectionCount++;
            }
            
            IASKSpecifier *newSpecifier = [[IASKSpecifier alloc] initWithSpecifier:specifier];
            [(NSMutableArray*)[dataSource objectAtIndex:sectionCount] addObject:newSpecifier];
            [newSpecifier release];
        }
    }
    [self setDataSource:dataSource];
>>>>>>> 3ad873577684c1e98c11cc081200e9d0402ad3b7
*/
}

/**
* Initialize default values for this settings
* Set them only if they are not included in defaults store
*/
-(void)setDefaultsForStore:(id<IASKSettingsStore>)store {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    Class boolClass = [@YES class];
    for (NSArray *items in self.dataSource) {
        for (id val in items) {
            if ([val isKindOfClass:[IASKSpecifier class]]) {
                IASKSpecifier *specifier = val;
                // if not in NSUserDefaults...
                NSString *specifierKey = specifier.key;
                if (specifierKey != nil && ![store objectForKey:specifier.key]) {
                    if (specifier.defaultValue != nil) {
                        // bool
                        if ([specifier.defaultValue isKindOfClass:[boolClass class]]) {
                            [store setBool:[specifier.defaultValue boolValue]  forKey:specifier.key];
                        } else
                        // int numbers
                        if (([specifier.defaultValue isKindOfClass:[NSNumber class]])) {
                            [store setInteger:[specifier.defaultValue intValue] forKey:specifier.key];
                        } else {
                            [store setObject: specifier.defaultValue forKey:specifier.key];
                        }
                    }
                }

            }
        }
    }
    [numberFormatter release];
}



- (BOOL)_sectionHasHeading:(NSInteger)section {
    return [[[[self dataSource] objectAtIndex:section] objectAtIndex:0] isKindOfClass:[NSDictionary class]];
}

- (NSInteger)numberOfSections {
    return [[self dataSource] count];
}

- (NSInteger)numberOfRowsForSection:(NSInteger)section {
    int headingCorrection = [self _sectionHasHeading:section] ? 1 : 0;
    return [(NSArray*)[[self dataSource] objectAtIndex:section] count] - headingCorrection;
}

- (IASKSpecifier*)specifierForIndexPath:(NSIndexPath*)indexPath {
    int headingCorrection = [self _sectionHasHeading:indexPath.section] ? 1 : 0;
    
    IASKSpecifier *specifier = [[[self dataSource] objectAtIndex:indexPath.section] objectAtIndex:(indexPath.row+headingCorrection)];
    specifier.settingsReader = self;
    return specifier;
}

- (NSIndexPath*)indexPathForKey:(NSString *)key {
    for (NSUInteger sectionIndex = 0; sectionIndex < self.dataSource.count; sectionIndex++) {
        NSArray *section = [self.dataSource objectAtIndex:sectionIndex];
        for (NSUInteger rowIndex = 0; rowIndex < section.count; rowIndex++) {
            IASKSpecifier *specifier = (IASKSpecifier*)[section objectAtIndex:rowIndex];
            if ([specifier isKindOfClass:[IASKSpecifier class]] && [specifier.key isEqualToString:key]) {
                NSUInteger correctedRowIndex = rowIndex - [self _sectionHasHeading:sectionIndex];
                return [NSIndexPath indexPathForRow:correctedRowIndex inSection:sectionIndex];
            }
        }
    }
    return nil;
}


- (IASKSpecifier*)specifierForKey:(NSString*)key {
    for (NSArray *specifiers in _dataSource) {
        for (id sp in specifiers) {
            if ([sp isKindOfClass:[IASKSpecifier class]]) {
                if ([[sp key] isEqualToString:key]) {
                    return sp;
                }
            }
        }
    }
    return nil;
}

- (NSString*)titleForSection:(NSInteger)section {
    if ([self _sectionHasHeading:section]) {
        NSDictionary *dict = [[[self dataSource] objectAtIndex:section] objectAtIndex:kIASKSectionHeaderIndex];
        return [self titleForStringId:[dict objectForKey:kIASKTitle]];
    }
    return nil;
}

- (NSString*)keyForSection:(NSInteger)section {
    if ([self _sectionHasHeading:section]) {
        return [[[[self dataSource] objectAtIndex:section] objectAtIndex:kIASKSectionHeaderIndex] objectForKey:kIASKKey];
    }
    return nil;
}

- (NSString*)footerTextForSection:(NSInteger)section {
    if ([self _sectionHasHeading:section]) {
        NSDictionary *dict = [[[self dataSource] objectAtIndex:section] objectAtIndex:kIASKSectionHeaderIndex];
        return [self titleForStringId:[dict objectForKey:kIASKFooterText]];
    }
    return nil;
}

- (NSString*)titleForStringId:(NSString*)stringId {
    return TSLocalizedString(stringId, @"");
}

- (NSString*)pathForImageNamed:(NSString*)image {
    return [[self.settingsBundle bundlePath] stringByAppendingPathComponent:image];
}

- (NSString *)platformSuffixForInterfaceIdiom:(UIUserInterfaceIdiom) interfaceIdiom {
    switch (interfaceIdiom) {
        case UIUserInterfaceIdiomPad: return @"~ipad";
        case UIUserInterfaceIdiomPhone: return @"~iphone";
    }
}

- (NSString *)file:(NSString *)file
        withBundle:(NSString *)bundle
            suffix:(NSString *)suffix
         extension:(NSString *)extension {
    
    NSString *appBundlePath = [self.applicationBundle bundlePath];
    bundle = [appBundlePath stringByAppendingPathComponent:bundle];
    file = [file stringByAppendingFormat:@"%@%@", suffix, extension];
    return [bundle stringByAppendingPathComponent:file];
    
}

- (NSString *)locateSettingsFile: (NSString *)file {
    static NSString* const kIASKBundleFolder = @"Settings.bundle";
    static NSString* const kIASKBundleFolderAlt = @"InAppSettings.bundle";
    
    static NSString* const kIASKBundleLocaleFolderExtension = @".lproj";

    // The file is searched in the following order:
    //
    // InAppSettings.bundle/FILE~DEVICE.inApp.plist
    // InAppSettings.bundle/FILE.inApp.plist
    // InAppSettings.bundle/FILE~DEVICE.plist
    // InAppSettings.bundle/FILE.plist
    // Settings.bundle/FILE~DEVICE.inApp.plist
    // Settings.bundle/FILE.inApp.plist
    // Settings.bundle/FILE~DEVICE.plist
    // Settings.bundle/FILE.plist
    //
    // where DEVICE is either "iphone" or "ipad" depending on the current
    // interface idiom.
    //
    // Settings.app uses the ~DEVICE suffixes since iOS 4.0.  There are some
    // differences from this implementation:
    // - For an iPhone-only app running on iPad, Settings.app will not use the
    //	 ~iphone suffix.  There is no point in using these suffixes outside
    //	 of universal apps anyway.
    // - This implementation uses the device suffixes on iOS 3.x as well.
    // - also check current locale (short only)
    
    NSArray *settingsBundleNames = @[kIASKBundleFolderAlt, kIASKBundleFolder];
    
    NSArray *extensions = @[@".inApp.plist", @".plist"];
    
    NSArray *plattformSuffixes = @[[self platformSuffixForInterfaceIdiom:UI_USER_INTERFACE_IDIOM()],
                                   @""];
    
    NSArray *languageFolders = @[[[[NSLocale preferredLanguages] objectAtIndex:0] stringByAppendingString:kIASKBundleLocaleFolderExtension],
                                 @""];
    
    NSString *path = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *settingsBundleName in settingsBundleNames) {
        for (NSString *extension in extensions) {
            for (NSString *platformSuffix in plattformSuffixes) {
                for (NSString *languageFolder in languageFolders) {
                    path = [self file:file
                           withBundle:[settingsBundleName stringByAppendingPathComponent:languageFolder]
                               suffix:platformSuffix
                            extension:extension];
                    if ([fileManager fileExistsAtPath:path]) {
                        goto exitFromNestedLoop;
                    }
                }
            }
        }
    }

exitFromNestedLoop:
    return path;
}

@end
