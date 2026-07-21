"
One token of a GcEncoding: its 1-based index, integer tokenId, the byte-level BPE piece string (byte-level-BPE space renders as U+0120 and newline as U+010A), the [byteStart, byteStop] span in the source's UTF-8 bytes (each byte-level char = exactly one source byte, so byteLength = piece size), and whether it is a special token (a '<|...|>' marker such as <|endoftext|>). displayPiece maps the byte-level whitespace markers to a visible middle dot / pilcrow for the teaching token-box view; boxElementBackground: builds the labelled box (piece over id) with a click that spawns this token object.
"
Class {
	#name : 'GcEncodedToken',
	#superclass : 'Object',
	#instVars : [
		'index',
		'tokenId',
		'piece',
		'byteStart',
		'byteStop',
		'special',
		'encoding'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'palette' }
GcEncodedToken class >> generatedColor [
	"Background for a greedily generated token box in a generation."
	^ Color r: 205 g: 232 b: 205 range: 255
]

{ #category : 'palette' }
GcEncodedToken class >> normalColor [
	"Background for an ordinary token box."
	^ Color r: 232 g: 238 b: 247 range: 255
]

{ #category : 'palette' }
GcEncodedToken class >> promptColor [
	"Background for a prompt token box in a generation."
	^ Color r: 220 g: 232 b: 247 range: 255
]

{ #category : 'palette' }
GcEncodedToken class >> specialColor [
	"Highlight background for a special / EOT token box."
	^ Color r: 255 g: 211 b: 122 range: 255
]

{ #category : 'displaying' }
GcEncodedToken >> boxBackgroundColor [
	^ self isSpecial
		ifTrue: [ self class specialColor ]
		ifFalse: [ self class normalColor ]
]

{ #category : 'displaying' }
GcEncodedToken >> boxElement [
	"The token box using the default (special vs ordinary) background."
	^ self boxElementBackground: self boxBackgroundColor
]

{ #category : 'displaying' }
GcEncodedToken >> boxElementBackground: aColor [
	"A teaching token box: the visible piece over its integer id, on aColor; a click spawns this token object."
	| box nameLabel numberLabel |
	box := BrVerticalPane new
		fitContent;
		alignCenter;
		margin: (BlInsets top: 2 left: 2 bottom: 5 right: 2);
		yourself.
	nameLabel := BrLabel new
		aptitude: (BrGlamorousLabelAptitude new fontSize: 20; glamorousCodeFont);
		geometry: (BlRoundedRectangleGeometry cornerRadius: 4);
		padding: (BlInsets all: 4);
		background: aColor;
		text: self displayPiece;
		yourself.
	numberLabel := BrLabel new
		margin: (BlInsets all: 1);
		aptitude: (BrGlamorousLabelAptitude new foreground: Color gray);
		beSmallSize;
		text: tokenId asString;
		yourself.
	box addChild: nameLabel; addChild: numberLabel.
	box when: BlClickEvent do: [ :e | e target phlow spawnObject: self ].
	^ box
]

{ #category : 'accessing' }
GcEncodedToken >> byteLength [
	"Number of source UTF-8 bytes this token covers (= piece char count)."
	^ (byteStart notNil and: [ byteStop notNil ])
		ifTrue: [ byteStop - byteStart + 1 ]
		ifFalse: [ piece size ]
]

{ #category : 'accessing' }
GcEncodedToken >> byteStart [
	^ byteStart
]

{ #category : 'accessing' }
GcEncodedToken >> byteStart: anInteger [
	byteStart := anInteger
]

{ #category : 'accessing' }
GcEncodedToken >> byteStop [
	^ byteStop
]

{ #category : 'accessing' }
GcEncodedToken >> byteStop: anInteger [
	byteStop := anInteger
]

{ #category : 'displaying' }
GcEncodedToken >> decodedText [
	"The text this token decodes to (best effort: a piece may split a multi-byte character, so fall back to the display piece)."
	^ [ GcGpt2Decoder default decodeId: tokenId ] on: Error do: [ :e | self displayPiece ]
]

{ #category : 'displaying' }
GcEncodedToken >> detailFacets [
	^ {
		'Index' -> index.
		'Id' -> tokenId.
		'Piece' -> piece.
		'Display' -> self displayPiece.
		'Decoded' -> self decodedText.
		'Byte start' -> byteStart.
		'Byte stop' -> byteStop.
		'Byte length' -> self byteLength.
		'Special' -> self isSpecial }
]

{ #category : 'displaying' }
GcEncodedToken >> displayPiece [
	"The piece with byte-level whitespace markers made visible: U+0120 (space) -> middle dot, U+010A (newline) -> pilcrow. Other byte-level chars are shown as-is."
	^ String streamContents: [ :s |
		piece do: [ :ch |
			ch asInteger = 288
				ifTrue: [ s nextPut: (Character value: 183) ]
				ifFalse: [
					ch asInteger = 266
						ifTrue: [ s nextPut: (Character value: 182) ]
						ifFalse: [ s nextPut: ch ] ] ] ]
]

{ #category : 'accessing' }
GcEncodedToken >> encoding [
	^ encoding
]

{ #category : 'accessing' }
GcEncodedToken >> encoding: aGcEncoding [
	encoding := aGcEncoding
]

{ #category : 'gt - views' }
GcEncodedToken >> gtDetailsFor: aView [
	<gtView>
	"What exactly is this token: id, piece, decoded text and byte span."
	^ aView columnedList
		title: 'Details';
		priority: 1;
		items: [ self detailFacets ];
		column: 'Facet' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc |
			assoc value isNil
				ifTrue: [ '-' ]
				ifFalse: [ assoc value displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'accessing' }
GcEncodedToken >> index [
	^ index
]

{ #category : 'accessing' }
GcEncodedToken >> index: anInteger [
	index := anInteger
]

{ #category : 'testing' }
GcEncodedToken >> isSpecial [
	"Whether this is a special / EOT token (a '<|...|>' marker such as <|endoftext|>)."
	^ special == true
]

{ #category : 'accessing' }
GcEncodedToken >> piece [
	^ piece
]

{ #category : 'accessing' }
GcEncodedToken >> piece: aString [
	piece := aString
]

{ #category : 'printing' }
GcEncodedToken >> printOn: aStream [
	aStream
		nextPutAll: 'token ';
		print: tokenId;
		nextPutAll: ' ';
		print: self displayPiece
]

{ #category : 'accessing' }
GcEncodedToken >> special [
	^ special
]

{ #category : 'accessing' }
GcEncodedToken >> special: aBoolean [
	special := aBoolean
]

{ #category : 'accessing' }
GcEncodedToken >> tokenId [
	^ tokenId
]

{ #category : 'accessing' }
GcEncodedToken >> tokenId: anInteger [
	tokenId := anInteger
]
