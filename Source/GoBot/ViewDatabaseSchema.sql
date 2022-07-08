-- version 1.14
-- added a few indexes

-- version 1.13
-- overhaul address table for dialing

-- version 1.12
-- change deleted to hidden (for moderation / soft-block)
-- add Blob.Metadata.averageColorRGB

-- version 1.11
-- add deleted column as temporary soft-delete

-- version 1.10
-- simplifiy contacts by removing the view

-- version 1.9
-- simplified channels to hashtags array
-- mostly the same structure but names are unique now

-- version 1.8 photo blobs
-- new table to save image blob references and meta data

-- version 1.7 - Channels
-- There are two occurances of channels in the ssb ecosystem.

-- The older `channel: "someString"` field n post messages.
-- let's call them legacy or v1.

-- main disadvantages:
--   * there can only be one chan per msg
--   * can't be edited (remove, typos, ...)

-- The newer ssb-tags (v2)
-- main advantage:
--   * can be assigned after posting a message
--   * can be re-named
--   * re-uses tangle concept

-- main disadvantages:
--   * re-uses type:about for names
--   * channel assignments and creates are on the same message type (even though the tangle would suffice)

-- the takeaway: it could be cleaner but it works.
-- legacy (v1) channel messages will be inserted witht the boolean field
-- edits (type:about) will be redicted to the channels table (not about, since that is for feeds only)
-- both assignments will go into the channel_assignments table

-- version 1.6
-- fix contact_latest relations
-- was still joining on rx_seq (see v1.3)

-- version 1.5
-- default isDecrypted to false

-- version 1.4
-- add addresses table
-- multiserver type:address is used by _modern_ pubs
--
-- TODO: profile indexing and make sure join fields are indexed

-- version 1.3
-- add extra column to messages for msg_id
-- reusing the rx_seq is troublesome
-- for instance, if we see lots of vote messages, these allocate ids in the mssageKeys table
-- the view of the rxlog then is missing messages, rx_seq needs to corrospond 1:1 to the createLogStream from the (go)bot

-- version 1.2
-- add table for private recps

-- version 1.1
-- contacts_latest view
-- change about_id to unique

-- SSB sqlite schema v1.0
-- inspired by usage as seen in patch{work/bay/foo}

-- i started making it with DbSchema.com but it already bit me a couple of times.
-- when serializing the designd schema to sqlite some of the index names were wrong
-- and in some cases it incorrectly merged multiple foreing keys into one.

-- overall idea #1: store identifiers (%asjdk.sha256) as len32 binary
-- in comparison: the base64encoded string is 53 bytes long
-- this should help the btree indicies immensly
-- DISCARDED: complicates handling from the swift bindings - maybe later as things get larger

-- improvement 1: One thing i'm not sure about yet is if we should use msg_key to join messages.
-- these are quire wide types (uint might be more compact)

-- UPDATE: yes! will introduce a maping table from %msgKey to msgSeqID as int

CREATE TABLE authors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    author TEXT UNIQUE,
    hashed TEXT UNIQUE NOT NULL
);

CREATE INDEX author_id on authors (id);
CREATE INDEX author_pubkey on authors (author);
CREATE INDEX authors_hashed ON authors(hashed);

CREATE TABLE messagekeys (
    id INTEGER PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    hashed TEXT UNIQUE NOT NULL
);
CREATE INDEX messagekeys_key ON messagekeys(key);
CREATE INDEX messagekeys_id ON messagekeys(id);
CREATE INDEX messagekeys_hashed ON messagekeys(hashed);

-- BUT: this is mostly just glossing over the fact msg_key is referencing our messages table.
-- the above remark is only true for root/branch on tangles and mention references
-- msg_key will only point to stored messages.

-- this table _just_ stores that there was a message. it's "untyped" so to speak.
-- ex: to get the author of a post and its timestamp you need to join posts and messages
CREATE TABLE messages (
    msg_id               INTEGER PRIMARY KEY,
    rx_seq               INTEGER UNIQUE, -- might have holes
    author_id            INTEGER NOT NULL,
    sequence             integer NOT NULL,
    type                 text NOT NULL,             -- needed so that we know what tables to merge for more info
    received_at          real NOT NULL,
    written_at           real NOT NULL,
    claimed_at           real DEFAULT 0,
    is_decrypted         BOOLEAN default false,
    
    hidden              BOOLEAN default false, -- for moderation/soft-delete
    
    -- this is a very naive way of requiring _unforked chain_
    -- a proper implementation would require checks on the previous field
    -- but all this is handled in go-ssb anyway
    CONSTRAINT simple_chain UNIQUE ( author_id, sequence ),

    FOREIGN KEY ( author_id ) REFERENCES authors( "id" ),
    FOREIGN KEY ( msg_id ) REFERENCES msgkeys( "id" )
);

-- make _needs refresh_ faster
CREATE INDEX messages_rxseq on messages (rx_seq);

-- make looking for authors fast
CREATE INDEX author ON messages ( author_id );

-- make looking for _what happend last week_ fast
CREATE INDEX msgs_received ON messages ( received_at );
CREATE INDEX msgs_claimed ON messages ( claimed_at );

CREATE INDEX msgs_decrypted on messages (is_decrypted);

-- indexes for new feed algorithim options
CREATE INDEX messages_idx_type_claimed_at ON messages(type, claimed_at);
CREATE INDEX messages_idx_author_received ON messages(author_id, received_at DESC);
CREATE INDEX messages_idx_author_type_sequence ON messages(author_id, type, sequence DESC);
CREATE INDEX messages_idx_is_decrypted_hidden_claimed_at ON messages(is_decrypted, hidden, claimed_at);
CREATE INDEX messages_idx_type_is_decrypted_hidden_author ON messages(type, is_decrypted, hidden, author_id);
CREATE INDEX messages_idx_type_is_decrypted_hidden_claimed_at ON messages(type, is_decrypted, hidden, claimed_at);
CREATE INDEX messages_idx_is_decrypted_hidden_author_claimed_at ON messages(is_decrypted, hidden, author_id, claimed_at);


-- quick profile listing
CREATE INDEX helper_profile on messages (is_decrypted, type, author_id, claimed_at);

-- unblock helper table
CREATE TABLE blocked_content (
    id integer not null, -- numerical id of the msg or author
    type integer not null -- 0 msg, 1 author
);

-- address
CREATE TABLE addresses (
    address_id   INTEGER PRIMARY KEY,
    about_id     integer not null, -- which feed this address is for
    address      text unique not null,  -- the multiserv encoded string i.e. "net:ip:port~shs:key"

    use          boolean default true, -- false means disabled, dont' dial
    worked_last  DATETIME default 0, -- last time a connection could be made
    last_err     text default "",
    redeemed     real default null
);

-- this just stores the text of a post
-- reply information is stored in tangles
-- mentions of people and artifacts are stored in the mention_ tables
CREATE TABLE posts (
msg_ref              integer not null,
is_root              boolean default false,
text                 text,
FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" )
);
CREATE INDEX posts_msgrefs on posts (msg_ref);
CREATE INDEX posts_roots on posts (is_root);
CREATE INDEX posts_root_mesgrefs ON posts(is_root, msg_ref);

-- reply trees aka tangles
-- a message in a thread (or hopefully soon gatherings) references the first message (root)
-- and all the branches it has seen.
-- for example a JSON post (with key %myMsg) could be
-- {
-- "text": "my message",
-- "root": "%theRootKey",
-- "branch": ["%reply1", "%otherReply2"],
-- }
-- The more I thought about it the most natural it seemd to unroll this into SQL like this
-- INSERT INTO TANGLES (%myMsg, %theRootKey); returns tangle_id
-- INSERT INTO BRANCHES (tangle_id, %reply1);
-- INSERT INTO BRANCHES (tangle_id, %otherReply2);
-- than this can be walked and merged as needed
-- TODO: could be more efficient to read it all up to the swift layer and condense it there into a tree
CREATE TABLE tangles (
    id              INTEGER PRIMARY KEY,
    msg_ref              integer not null,
    root                 integer not null,
    FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
    FOREIGN KEY ( root ) REFERENCES messages( "msg_id" )
);
CREATE INDEX tangle_roots on tangles (root);
CREATE INDEX tangle_msgref on tangles (msg_ref);
CREATE INDEX tangle_id on tangles (id);
CREATE INDEX tangles_roots_and_msg_refs ON tangles(root, msg_ref);

CREATE TABLE branches (
    tangle_id       integer not null,
    branch          integer not null,
    FOREIGN KEY ( tangle_id )   REFERENCES tangles( "id" ),
    FOREIGN KEY ( branch )      REFERENCES messages( "msg_id" )
);


-- posts can mention people
CREATE TABLE mention_feed (
msg_ref              integer not null,
feed_id              integer NOT NULL,
name                 text,
FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
FOREIGN KEY ( feed_id ) REFERENCES authors( "id" )
);
CREATE INDEX mention_feed_refs on mention_feed (msg_ref);
CREATE INDEX mention_feed_author on mention_feed (feed_id);
CREATE INDEX mention_feed_author_refs on mention_feed (feed_id, msg_ref);

-- posts can mention other messages (backlinks)
CREATE TABLE mention_message (
msg_ref              integer not null,
link_id              integer not null,
FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
FOREIGN KEY ( link_id ) REFERENCES messages( "msg_id" )
);
CREATE INDEX mention_msg_refs on mention_message (msg_ref);

-- posts can mention images (backlinks)
CREATE TABLE mention_image (
msg_ref              integer not null,
image                text, -- blob ID table?
name                 text, -- filename
FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" )
);
CREATE INDEX mention_img_refs on mention_image (msg_ref);

-- posts can contain multiple blobs
CREATE TABLE post_blobs (
msg_ref                 integer not null,
identifier              text, -- TODO: blob hash:id table
name                    text,
meta_bytes              integer,
meta_widht              integer,
meta_height             integer,
meta_mime_type          text,
meta_average_color_rgb  integer,
FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" )
);
CREATE INDEX post_blobs_refs on post_blobs (msg_ref);


-- somebody dug/liked a thing
CREATE TABLE votes (
msg_ref              integer not null,
link_id              integer NOT NULL,
value                integer,
expression           text,
FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
FOREIGN KEY ( link_id ) REFERENCES msgkeys( "id" )
);
CREATE INDEX votes_msgrefs on votes (msg_ref);

-- describing someone (or thing like gatherings or git-ssb repo names)
-- about field is _what/who is this about_. author of the message is in the messages table
CREATE TABLE abouts (
msg_ref              integer not null,
about_id             integer NOT NULL UNIQUE,
name                 text,
image                text,
description          text,
publicWebHosting     boolean,
FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
FOREIGN KEY ( about_id ) REFERENCES auhtors( "id" )
);

-- friend/block relations
-- if your mathy: this is like a adjacency matrix for the whole graph
-- you can ask _all follows by me_ or _who is following me_
CREATE TABLE contacts (
msg_ref              integer not null, -- latest message, for timestamps and sequence
author_id            integer not null,
contact_id           integer not null,
-- states:
-- 0 not-following (can be dropped)
-- 1 following
-- -1 blocking
state                integer,
CONSTRAINT only_one_relation UNIQUE ( author_id, contact_id ),
FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
FOREIGN KEY ( author_id ) REFERENCES authors( "msg_id" ),
FOREIGN KEY ( contact_id ) REFERENCES authors( "id" )
);

CREATE INDEX contacts_state ON contacts (contact_id, state);
CREATE INDEX contacts_state_with_author ON contacts (author_id, contact_id, state);
CREATE INDEX contacts_msg_ref ON contacts(msg_ref);
CREATE INDEX contacts_state_and_author ON contacts(state, author_id);

-- private recps
-- TODO: until we have changing groups, it would be enough to save these for the first message
CREATE TABLE private_recps (
    msg_ref     integer not null,
    contact_id  integer not null,
    FOREIGN KEY ( contact_id ) REFERENCES authors( "id" ),
    FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" )
);

-- what channels are there
CREATE TABLE channels (
    id      INTEGER PRIMARY KEY,
    name    text unique,
    legacy  boolean default false -- v1 channel / simple name on object / maybe from mentions?!
);

-- m:n style table to assign messages to channels
CREATE TABLE channel_assignments (
    msg_ref  integer not null,
    chan_ref integer not null,
    FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
    FOREIGN KEY ( chan_ref ) REFERENCES channels( "id" )
);

CREATE INDEX channel_assignments_msg_refs ON channel_assignments(msg_ref);
CREATE INDEX channel_assignments_chan_ref_and_msg_ref ON channel_assignments(chan_ref, msg_ref);

CREATE TABLE reports (
    msg_ref integer not null,
    author_id integer not null,
    type text NOT NULL,
    created_at real NOT NULL,
    FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
    FOREIGN KEY ( author_id ) REFERENCES authors( "id" )
);

CREATE INDEX reports_author_created_at ON reports(author_id, created_at DESC);
CREATE INDEX reports_msg_ref ON reports(msg_ref);
CREATE INDEX reports_msg_ref_author ON reports(msg_ref, author_id;

CREATE TABLE pubs (
    msg_ref integer not null,
    host text not null,
    port integer not null,
    key text not null,
    FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" )
);

CREATE INDEX pubs_index ON pubs(msg_ref);
