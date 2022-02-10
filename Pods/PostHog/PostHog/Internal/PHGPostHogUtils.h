#import <Foundation/Foundation.h>
#import "PHGSerializableValue.h"

NS_ASSUME_NONNULL_BEGIN

NSString *createUUIDString(void);

// Validation Utils
BOOL serializableDictionaryTypes(NSDictionary *dict);

// Date Utils
NSString *createISO8601FormattedString(NSDate *date);

void trimQueueItems(NSMutableArray *array, NSUInteger size);

// Async Utils
dispatch_queue_t phg_dispatch_queue_create_specific(const char *label,
                                                    dispatch_queue_attr_t _Nullable attr);
BOOL phg_dispatch_is_on_specific_queue(dispatch_queue_t queue);
void phg_dispatch_specific(dispatch_queue_t queue, dispatch_block_t block,
                           BOOL waitForCompletion);
void phg_dispatch_specific_async(dispatch_queue_t queue,
                                 dispatch_block_t block);
void phg_dispatch_specific_sync(dispatch_queue_t queue, dispatch_block_t block);

// Logging

void PHGSetShowDebugLogs(BOOL showDebugLogs);
void PHGLog(NSString *format, ...);

// JSON Utils

JSON_DICT PHGCoerceDictionary(NSDictionary *_Nullable dict);

NSString *PHGEventNameForScreenTitle(NSString *title);

// Deep copy and check NSCoding conformance
@protocol PHGSerializableDeepCopy <NSObject>
-(id _Nullable) serializableDeepCopy;
@end

@interface NSDictionary(SerializableDeepCopy) <PHGSerializableDeepCopy>
@end

@interface NSArray(SerializableDeepCopy) <PHGSerializableDeepCopy>
@end


NS_ASSUME_NONNULL_END
