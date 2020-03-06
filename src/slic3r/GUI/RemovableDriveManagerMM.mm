#import "RemovableDriveManager.hpp"
#import "RemovableDriveManagerMM.h"
#import "GUI_App.hpp"
#import <AppKit/AppKit.h> 
#import <DiskArbitration/DiskArbitration.h>

@implementation RemovableDriveManagerMM



-(instancetype) init
{
	self = [super init];
	//if(self){}
	return self;
}
-(void) on_device_unmount: (NSNotification*) notification
{
    //NSLog(@"on device change");
    Slic3r::GUI::wxGetApp().removable_drive_manager()->update(0);
}
-(void) add_unmount_observer
{
    //NSLog(@"add unmount observer");
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(on_device_unmount:) name:NSWorkspaceDidUnmountNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(on_device_unmount:) name:NSWorkspaceDidMountNotification object:nil];
}
-(NSArray*) list_dev
{
    // DEPRICATED:
    //NSArray* devices = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
	//return devices;
    
    NSArray *mountedRemovableMedia = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:nil options:NSVolumeEnumerationSkipHiddenVolumes];
    NSMutableArray *result = [NSMutableArray array];
    for(NSURL *volURL in mountedRemovableMedia)
    {
        int                 err = 0;
        DADiskRef           disk;
        DASessionRef        session;
        CFDictionaryRef     descDict;
        session = DASessionCreate(NULL);
        if (session == NULL) {
            err = EINVAL;
        }
        if (err == 0) {
            disk = DADiskCreateFromVolumePath(NULL,session,(CFURLRef)volURL);
            if (session == NULL) {
                err = EINVAL;
            }
        }
        if (err == 0) {
            descDict = DADiskCopyDescription(disk);
            if (descDict == NULL) {
                err = EINVAL;
            }
        }
        if (err == 0) {
            CFTypeRef mediaEjectableKey = CFDictionaryGetValue(descDict,kDADiskDescriptionMediaEjectableKey);
            BOOL ejectable = [mediaEjectableKey boolValue];
            CFTypeRef deviceProtocolName = CFDictionaryGetValue(descDict,kDADiskDescriptionDeviceProtocolKey);
            CFTypeRef deviceModelKey = CFDictionaryGetValue(descDict, kDADiskDescriptionDeviceModelKey);
            if (mediaEjectableKey != NULL)
            {
                BOOL op = ejectable && (CFEqual(deviceProtocolName, CFSTR("USB")) || CFEqual(deviceModelKey, CFSTR("SD Card Reader")));
                //!CFEqual(deviceModelKey, CFSTR("Disk Image"));
                //
                if (op) {
                    [result addObject:volURL.path];
                }
            }
        }
        if (descDict != NULL) {
            CFRelease(descDict);
        }
        
        
    }
    return result;
}

//this eject drive is not used now
-(void)eject_drive:(NSString *)path
{
    DADiskRef disk;
    DASessionRef session;
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    int err = 0;
    session = DASessionCreate(NULL);
    if (session == NULL) {
        err = EINVAL;
    }
    if (err == 0) {
        disk = DADiskCreateFromVolumePath(NULL,session,(CFURLRef)url);
    }
    if( err == 0)
    {
        DADiskUnmount(disk, kDADiskUnmountOptionDefault,
                      NULL, NULL);
    }
    if (disk != NULL) {
        CFRelease(disk);
    }
    if (session != NULL) {
        CFRelease(session);
    }
}

@end

namespace Slic3r {
namespace GUI {

void RemovableDriveManager::register_window_osx()
{
    assert(m_impl_osx == nullptr);
    m_impl_osx = [[RemovableDriveManagerMM alloc] init];
	if (m_impl_osx)
		[m_impl_osx add_unmount_observer];
}

void RemovableDriveManager::unregister_window_osx()
{
    if (m_impl_osx)
        [m_impl_osx release];
}

namespace search_for_drives_internal 
{
    void inspect_file(const std::string &path, const std::string &parent_path, std::vector<DriveData> &out);
}

void RemovableDriveManager::list_devices(RemovableDriveManager& parent, std::vector<DriveData> &out) const
{
    assert(m_impl_osx != nullptr);
    if (m_impl_osx) {
    	NSArray* devices = [m_impl_osx list_dev];
    	for (NSString* volumePath in devices)
        	search_for_drives_internal::inspect_file(std::string([volumePath UTF8String]), "/Volumes", out);
    }
}

// not used as of now
void RemovableDriveManager::eject_device(const std::string &path)
{
    assert(m_impl_osx != nullptr);
    if (m_impl_osx) {
        NSString * pth = [NSString stringWithCString:path.c_str()
                                            encoding:[NSString defaultCStringEncoding]];
        [m_impl_osx eject_drive:pth];
    }
}

}}//namespace Slicer::GUI
