"
GPT-2 byte-level BPE DECODER (decode only; the encoder is a later push). Loads vocab.json (piece -> id) and inverts it (idToPiece), and builds the INVERSE of GPT-2's bytes_to_unicode map (byteDecoder: unicode codepoint -> byte 0..255). decodeIds: maps each token id to its unicode piece, each unicode char back to a byte, accumulates all bytes, then utf8-decodes the whole buffer once. Two gotchas honored: the codepoint list is copied with OrderedCollection withAll: (never asOrderedCollection, which aliases), and bytes accumulate through a WriteStream on: ByteArray new (never ByteArray withAll:).
"
Class {
	#name : 'GcGpt2Decoder',
	#superclass : 'Object',
	#instVars : [
		'idToPiece',
		'byteDecoder'
	],
	#classVars : [
		'DefaultDecoder'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcGpt2Decoder class >> cachePath [
	"Local glassbox cache directory holding the GPT-2 vocab/merges/weights."
	^ FileLocator home / '.cache' / 'glassbox' / 'gpt2'
]

{ #category : 'instance creation' }
GcGpt2Decoder class >> default [
	"A memoized shared decoder so the vocab is parsed at most once per image."
	^ DefaultDecoder ifNil: [ DefaultDecoder := self openDefault ]
]

{ #category : 'instance creation' }
GcGpt2Decoder class >> openDefault [
	"Load vocab.json from the local glassbox cache and build a fresh decoder."
	| vocab |
	vocab := STONJSON fromString: (self cachePath / 'vocab.json') contents.
	^ self new initializeFromVocab: vocab; yourself
]

{ #category : 'instance creation' }
GcGpt2Decoder class >> reset [
	"Drop the memoized default decoder."
	DefaultDecoder := nil
]

{ #category : 'initialization' }
GcGpt2Decoder >> buildByteDecoder [
	"Build the INVERSE of GPT-2's bytes_to_unicode map: unicode codepoint -> byte (0..255). bs is the list of byte values; cs the matching unicode codepoints. The initial cs is copied with OrderedCollection withAll: (NOT asOrderedCollection, which would alias bs and corrupt the map as bs grows)."
	| bs cs n decoder |
	bs := OrderedCollection new.
	33 to: 126 do: [ :b | bs add: b ].
	161 to: 172 do: [ :b | bs add: b ].
	174 to: 255 do: [ :b | bs add: b ].
	cs := OrderedCollection withAll: bs.
	n := 0.
	0 to: 255 do: [ :b |
		(bs includes: b) ifFalse: [
			bs add: b.
			cs add: 256 + n.
			n := n + 1 ] ].
	decoder := Dictionary new.
	1 to: bs size do: [ :i | decoder at: (cs at: i) put: (bs at: i) ].
	^ decoder
]

{ #category : 'accessing' }
GcGpt2Decoder >> byteDecoder [
	^ byteDecoder
]

{ #category : 'decoding' }
GcGpt2Decoder >> decodeId: anId [
	"Decode a single token id to its String piece."
	^ self decodeIds: { anId }
]

{ #category : 'decoding' }
GcGpt2Decoder >> decodeIds: aCollectionOfIds [
	"Decode token ids to a String. Each id maps to a unicode piece; each unicode char maps back to a byte via byteDecoder; all bytes accumulate through a single WriteStream on: ByteArray new (NOT ByteArray withAll:), and the whole byte buffer is utf8-decoded once at the end."
	| stream |
	stream := WriteStream on: ByteArray new.
	aCollectionOfIds do: [ :id |
		| piece |
		piece := idToPiece at: id ifAbsent: [ nil ].
		piece ifNotNil: [
			piece do: [ :ch | stream nextPut: (byteDecoder at: ch asInteger) ] ] ].
	^ stream contents utf8Decoded
]

{ #category : 'accessing' }
GcGpt2Decoder >> idToPiece [
	^ idToPiece
]

{ #category : 'initialization' }
GcGpt2Decoder >> initializeFromVocab: aVocabDictionary [
	"Invert the piece -> id vocab into idToPiece and build the byte decoder."
	idToPiece := Dictionary new.
	aVocabDictionary keysAndValuesDo: [ :piece :id | idToPiece at: id put: piece ].
	byteDecoder := self buildByteDecoder
]

{ #category : 'accessing' }
GcGpt2Decoder >> pieceForId: anId [
	"The raw unicode BPE piece for a token id (before byte-decoding), or nil."
	^ idToPiece at: anId ifAbsent: [ nil ]
]
