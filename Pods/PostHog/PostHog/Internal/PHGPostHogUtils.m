#import "PHGPostHogUtils.h"

static BOOL kPostHogLoggerShowLogs = NO;

NSString *createUUIDString()
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *UUIDString = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return UUIDString;
}

// Date Utils
NSString *createISO8601FormattedString(NSDate *date)
{
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS'Z'";
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    });
    return [dateFormatter stringFromDate:date];
}

/** trim the queue so that it contains only upto `max` number of elements. */
void trimQueueItems(NSMutableArray *queue, NSUInteger max)
{
    if (queue.count < max) {
        return;
    }

    // Previously we didn't cap the queue. Hence there are cases where
    // the queue may already be larger than 1000 events. Delete as many
    // events as required to trim the queue size.
    NSRange range = NSMakeRange(0, queue.count - max);
    [queue removeObjectsInRange:range];
}

// Async Utils
dispatch_queue_t
phg_dispatch_queue_create_specific(const char *label,
                                   dispatch_queue_attr_t attr)
{
    dispatch_queue_t queue = dispatch_queue_create(label, attr);
    dispatch_queue_set_specific(queue, (__bridge const void *)queue,
                                (__bridge void *)queue, NULL);
    return queue;
}

BOOL phg_dispatch_is_on_specific_queue(dispatch_queue_t queue)
{
    return dispatch_get_specific((__bridge const void *)queue) != NULL;
}

void phg_dispatch_specific(dispatch_queue_t queue, dispatch_block_t block,
                           BOOL waitForCompletion)
{
    dispatch_block_t autoreleasing_block = ^{
        @autoreleasepool
        {
            block();
        }
    };
    if (dispatch_get_specific((__bridge const void *)queue)) {
        autoreleasing_block();
    } else if (waitForCompletion) {
        dispatch_sync(queue, autoreleasing_block);
    } else {
        dispatch_async(queue, autoreleasing_block);
    }
}

void phg_dispatch_specific_async(dispatch_queue_t queue,
                                 dispatch_block_t block)
{
    phg_dispatch_specific(queue, block, NO);
}

void phg_dispatch_specific_sync(dispatch_queue_t queue,
                                dispatch_block_t block)
{
    phg_dispatch_specific(queue, block, YES);
}

// Logging

void PHGSetShowDebugLogs(BOOL showDebugLogs)
{
    kPostHogLoggerShowLogs = showDebugLogs;
}

void PHGLog(NSString *format, ...)
{
    if (!kPostHogLoggerShowLogs)
        return;

    va_list args;
    va_start(args, format);
    NSLogv(format, args);
    va_end(args);
}

// JSON Utils

static id PHGCoerceJSONObject(id obj)
{
    // if the object is a NSString, NSNumber
    // then we're good
    if ([obj isKindOfClass:[NSString class]] ||
        [obj isKindOfClass:[NSNumber class]] ||
        [obj isKindOfClass:[NSNull class]]) {
        return obj;
    }

    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray array];
        for (id i in obj) {
            NSObject *value = i;
            // Hotfix: Storage format should support NSNull instead
            if ([value isKindOfClass:[NSNull class]]) {
                value = [NSData data];
            }
            [array addObject:PHGCoerceJSONObject(value)];
        }
        return array;
    }

    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        for (NSString *key in obj) {
            NSObject *value = obj[key];
            if (![key isKindOfClass:[NSString class]])
                PHGLog(@"warning: dictionary keys should be strings. got: %@. coercing "
                       @"to: %@",
                       [key class], [key description]);
            dict[key.description] = PHGCoerceJSONObject(value);
        }
        return dict;
    }

    if ([obj isKindOfClass:[NSDate class]])
        return createISO8601FormattedString(obj);

    if ([obj isKindOfClass:[NSURL class]])
        return [obj absoluteString];

    // default to sending the object's description
    PHGLog(@"warning: dictionary values should be valid json types. got: %@. "
           @"coercing to: %@",
           [obj class], [obj description]);
    return [obj description];
}

NSDictionary *PHGCoerceDictionary(NSDictionary *dict)
{
    // make sure that a new dictionary exists even if the input is null
    dict = dict ?: @{};
    // assert that the proper types are in the dictionary
    dict = [dict serializableDeepCopy];
    // coerce urls, and dates to the proper format
    return PHGCoerceJSONObject(dict);
}

NSString *PHGEventNameForScreenTitle(NSString *title)
{
    return [[NSString alloc] initWithFormat:@"Viewed %@ Screen", title];
}


@implementation NSDictionary(SerializableDeepCopy)

- (NSDictionary *)serializableDeepCopy
{
    NSMutableDictionary *returnDict = [[NSMutableDictionary alloc] initWithCapacity:self.count];
    NSArray *keys = [self allKeys];
    for (id key in keys) {
        id aValue = [self objectForKey:key];
        id theCopy = nil;
        
        if (![aValue conformsToProtocol:@protocol(NSCoding)]) {
#ifdef DEBUG
            NSAssert(FALSE, @"key `%@` doesn't conform to NSCoding and can't be serialized for delivery.", key);
#else
            PHGLog(@"key `%@` doesn't conform to NSCoding and can't be serialized for delivery.", key);
            // simply leave it out since we can't encode it anyway.
            continue;
#endif
        }
        
        if ([aValue conformsToProtocol:@protocol(PHGSerializableDeepCopy)]) {
            theCopy = [aValue serializableDeepCopy];
        } else if ([aValue conformsToProtocol:@protocol(NSCopying)]) {
            theCopy = [aValue copy];
        } else {
            theCopy = aValue;
        }
        
        [returnDict setValue:theCopy forKey:key];
  }
    
  return [returnDict copy];
}

@end


@implementation NSArray(SerializableDeepCopy)

-(NSArray *)serializableDeepCopy
{
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:self.count];
    
    for (id aValue in self) {
        id theCopy = nil;
        
        if (![aValue conformsToProtocol:@protocol(NSCoding)]) {
#ifdef DEBUG
            NSAssert(FALSE, @"type `%@` doesn't conform to NSCoding and can't be serialized for delivery.", NSStringFromClass([aValue class]));
#else
            PHGLog(@"type `%@` doesn't conform to NSCoding and can't be serialized for delivery.", NSStringFromClass([aValue class]));
            // simply leave it out since we can't encode it anyway.
            continue;
#endif
        }
        
        if ([aValue conformsToProtocol:@protocol(PHGSerializableDeepCopy)]) {
            theCopy = [aValue serializableDeepCopy];
        } else if ([aValue conformsToProtocol:@protocol(NSCopying)]) {
            theCopy = [aValue copy];
        } else {
            theCopy = aValue;
        }
        [returnArray addObject:theCopy];
    }
    
    return [returnArray copy];
}

@end
