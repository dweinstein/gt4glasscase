"
The result of encoding a source String with GcTokenizer's GPT-2 byte-level BPE encoder: the original sourceString, the ordered GcEncodedTokens (each with id, piece, byte span, special flag) and the producing tokenizer. tokenIds / pieces expose the plain arrays; decodedText round-trips back through the decoder (equals sourceString). gtTokenizedFor: is the teaching token-box view (each token a box with the visible piece over its integer id, special tokens highlighted, wrapping across the pane, a box click spawning the GcEncodedToken); gtTokensFor: is the tabular columnedList that drills into the token objects.
"
Class {
	#name : 'GcEncoding',
	#superclass : 'Object',
	#instVars : [
		'sourceString',
		'tokens',
		'tokenizer'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcEncoding >> decodedText [
	"The tokens decoded back to text; equals sourceString for a faithful round-trip."
	^ GcGpt2Decoder default decodeIds: self tokenIds
]

{ #category : 'gt - views' }
GcEncoding >> gtSourceFor: aView [
	<gtView>
	"The original source string."
	^ aView textEditor
		title: 'Source';
		priority: 3;
		text: [ sourceString ]
]

{ #category : 'gt - views' }
GcEncoding >> gtTokenizedFor: aView [
	<gtView>
	"The teaching token-box view: each token a labelled box (visible piece over its id), special tokens highlighted, wrapping across the pane; a box click spawns the GcEncodedToken."
	^ aView explicit
		title: 'Tokenized';
		priority: 1;
		stencil: [ self tokenBoxesElement ]
]

{ #category : 'gt - views' }
GcEncoding >> gtTokensFor: aView [
	<gtView>
	"Tabular tokens: position, id, visible piece and special flag; a row click drills into the GcEncodedToken."
	^ aView columnedList
		title: 'Tokens';
		priority: 2;
		items: [ tokens ];
		column: '#' text: [ :t | t index asString ];
		column: 'Id' text: [ :t | t tokenId asString ];
		column: 'Piece' text: [ :t | t displayPiece ];
		column: 'Special' text: [ :t | t isSpecial ifTrue: [ 'special' ] ifFalse: [ '' ] ];
		send: [ :t | t ]
]

{ #category : 'accessing' }
GcEncoding >> pieces [
	"The byte-level BPE piece strings as a plain Array."
	^ (tokens collect: [ :t | t piece ]) asArray
]

{ #category : 'printing' }
GcEncoding >> printOn: aStream [
	aStream
		nextPutAll: 'GcEncoding(';
		print: self tokenCount;
		nextPutAll: ' tokens)'
]

{ #category : 'accessing' }
GcEncoding >> sourceString [
	^ sourceString
]

{ #category : 'accessing' }
GcEncoding >> sourceString: aString [
	sourceString := aString
]

{ #category : 'displaying' }
GcEncoding >> tokenBoxesElement [
	"The wrapping row of teaching token boxes (visible piece over its id), special tokens highlighted; a box click spawns its GcEncodedToken."
	| flow |
	flow := BrHorizontalFlow new
		matchParent;
		padding: (BlInsets all: 10);
		yourself.
	tokens do: [ :t | flow addChild: t boxElement ].
	^ flow
]

{ #category : 'accessing' }
GcEncoding >> tokenCount [
	^ tokens size
]

{ #category : 'accessing' }
GcEncoding >> tokenIds [
	"The token ids as a plain Array."
	^ (tokens collect: [ :t | t tokenId ]) asArray
]

{ #category : 'accessing' }
GcEncoding >> tokenizer [
	^ tokenizer
]

{ #category : 'accessing' }
GcEncoding >> tokenizer: aTokenizer [
	tokenizer := aTokenizer
]

{ #category : 'accessing' }
GcEncoding >> tokens [
	"The ordered GcEncodedTokens."
	^ tokens
]

{ #category : 'accessing' }
GcEncoding >> tokens: aCollection [
	tokens := aCollection
]
