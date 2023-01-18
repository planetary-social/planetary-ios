//
//  GoSSB.h
//  GoSSB
//
//  Created by Matthew Lorentz on 1/5/22.
//

#ifndef GOSSB_H
#define GOSSB_H

#include <sys/types.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct { const char *p; size_t n; } gostring_t;

// err is one of:
// 0 - no error
// 1 - unknown error
// 2 - alias is already taken
typedef struct ssbRoomsAliasRegisterReturn {
  char* alias;
  int err;
} ssbRoomsAliasRegisterReturn_t;

typedef bool (notifyBlobHandle_t)(int64_t, const char*);
typedef bool (notifyMigrationOnRunning_t)(int64_t migrationIndex, int64_t migrationsCount);
typedef bool (notifyMigrationOnError_t)(int64_t migrationIndex, migint64_t migrationsCount, int64_t error);
typedef bool (notifyMigrationOnDone_t)(int64_t migrationsCount);
typedef void (fsckProgressHandle_t)(double, const char*);

extern const char *ssbVersion(void);

extern char* ssbGenKey(void);

extern bool ssbBotIsRunning(void);
extern bool ssbBotInit(gostring_t configPath, notifyBlobHandle_t blobFn, notifyMigrationOnRunning_t migrationOnRunningFn, notifyMigrationOnError_t migrationOnErrorFn, notifyMigrationOnDone_t migrationOnDoneFn);
extern bool ssbBotStop(void);
extern char* ssbBotStatus(void);

extern int ssbOffsetFSCK(uint32_t mode, fsckProgressHandle_t updateFn);
extern char* ssbHealRepo(void);

extern bool ssbInviteAccept(gostring_t token);

extern int ssbNullContent(gostring_t author, uint64_t sequence);
extern int ssbNullFeed(gostring_t author);

extern void ssbFeedReplicate(gostring_t feed);
extern void ssbFeedBlock(gostring_t feed, bool yes);

extern char* ssbPublish(gostring_t content);
extern char* ssbPublishPrivate(gostring_t content, gostring_t recipients);

extern int ssbTestingMakeNamedKey(gostring_t nick);
extern char* ssbTestingAllNamedKeypairs();
extern char* ssbTestingPublishAs(gostring_t nick, gostring_t content);
extern char* ssbTestingPublishPrivateAs(gostring_t nick, gostring_t content, gostring_t recipients);

extern char* ssbRepoStats(void);

extern char* ssbStreamRootLog(uint64_t seq, int limit);
extern char* ssbStreamPrivateLog(uint64_t seq, int limit);
extern char* ssbStreamPublishedLog(int64_t seq);

// returns true if the connection was successfull
extern bool ssbConnectPeer(gostring_t multisrv);

extern bool ssbDisconnectAllPeers(void);
extern uint ssbOpenConnections(void);

extern bool ssbBlobsWant(gostring_t ref);
extern char* ssbBlobsAdd(int32_t fd);

extern char* ssbRoomsListAliases(gostring_t address);
extern ssbRoomsAliasRegisterReturn_t ssbRoomsAliasRegister(gostring_t address, gostring_t alias);
extern bool ssbRoomsAliasRevoke(gostring_t address, gostring_t alias);

extern char* ssbGetRawMessage(gostring_t feedRef, uint64_t seq);

#endif
