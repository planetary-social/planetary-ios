#ifndef GOSSB_H
#define GOSSB_H

#include <sys/types.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct { const char *p; size_t n; } gostring_t;

typedef bool (blobNotifyHandle_t)(int64_t, const char*);

extern const char *ssbVersion(void);

extern char* ssbGenKey(void);

extern bool ssbBotIsRunning(void);
extern bool ssbBotInit(gostring_t configPath, blobNotifyHandle_t notifyFn);
extern bool ssbBotStop(void);
extern char* ssbBotStatus(void);

extern int ssbOffsetFSCK(uint32_t mode);
extern char* ssbHealRepo(void);

extern bool ssbInviteAccept(gostring_t token);

extern int ssbNullContent(gostring_t author, uint64_t sequence);
extern int ssbNullFeed(gostring_t author);

extern char* ssbPublish(gostring_t content);
extern char* ssbPublishPrivate(gostring_t content, gostring_t recipients);

#ifdef DEBUG
extern int ssbTestingMakeNamedKey(gostring_t nick);
extern char* ssbTestingAllNamedKeypairs();
extern char* ssbTestingPublishAs(gostring_t nick, gostring_t content);
extern char* ssbTestingPublishPrivateAs(gostring_t nick, gostring_t content, gostring_t recipients);
#endif

extern char* ssbRepoStats(void);
extern int ssbReplicateUpTo(void);

extern char* ssbStreamRootLog(uint64_t seq, int limit);
extern char* ssbStreamPrivateLog(uint64_t seq, int limit);

// returns true if the connection was successfull
extern bool ssbConnectPeer(gostring_t multisrv);

// waits for new messages or returns onces t seconds have passed if nothing happend
extern int64_t ssbWaitForNewMessages(int32_t t);

extern bool ssbDisconnectAllPeers(void);
extern uint ssbOpenConnections(void);

extern bool ssbBlobsWant(gostring_t ref);
extern int ssbBlobsGet(gostring_t ref);
extern char* ssbBlobsAdd(int32_t fd);

#endif
