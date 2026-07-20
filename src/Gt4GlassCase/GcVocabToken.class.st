"
One tokenizer vocabulary entry with anomaly flags computed from the vocab alone: special, byte token, reserved or unused pattern, control or replacement characters, unreachable by BPE merges. Flagged tokens are natural trigger candidates (SolidGoldMagikarp family). GcUndertrainedToken is the embedding-norm refinement of the same idea: an undertrained token IS a vocab token plus an anomaly verdict, and should reference a GcVocabToken rather than re-model id and text.
"
Class {
	#name : 'GcVocabToken',
	#superclass : 'Object',
	#instVars : [
		'tokenId',
		'text',
		'flags',
		'mergeRank'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcVocabToken class >> id: anInteger text: aString [
	| token |
	token := self new.
	token tokenId: anInteger.
	token text: aString.
	token flags: Set new.
	^ token
]

{ #category : 'accessing' }
GcVocabToken >> addFlag: aSymbol [
	self flags add: aSymbol
]

{ #category : 'accessing' }
GcVocabToken >> detailFacets [
	^ {
		'Id' -> self tokenId.
		'Text' -> self text.
		'Rendered' -> self text printString.
		'UTF-8 bytes' -> self hexBytes.
		'Length' -> self text size.
		'Flags' -> self flagsString }
]

{ #category : 'accessing' }
GcVocabToken >> flags [
	^ flags ifNil: [ flags := Set new ]
]

{ #category : 'accessing' }
GcVocabToken >> flags: aSet [
	flags := aSet
]

{ #category : 'accessing' }
GcVocabToken >> flagsString [
	| names |
	names := (self flags collect: [ :f | f asString ]) asSortedCollection asArray.
	^ names inject: '' into: [ :acc :each |
		acc isEmpty
			ifTrue: [ each ]
			ifFalse: [ acc , ' ' , each ] ]
]

{ #category : 'views' }
GcVocabToken >> gtDetailsFor: aView [
	<gtView>
	"What exactly is this token, byte by byte?"
	^ aView columnedList
		title: 'Details';
		priority: 1;
		items: [ self detailFacets ];
		column: 'Facet' text: [ :assoc | assoc key asString ];
		column: 'Value' text: [ :assoc |
			| v |
			v := assoc value.
			v isNil
				ifTrue: [ '-' ]
				ifFalse: [
					(v isCollection and: [ v isString not ])
						ifTrue: [ v printString ]
						ifFalse: [ v displayString ] ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'testing' }
GcVocabToken >> hasFlag: aSymbol [
	^ self flags includes: aSymbol
]

{ #category : 'accessing' }
GcVocabToken >> hexBytes [
	^ self text utf8Encoded hex
]

{ #category : 'testing' }
GcVocabToken >> isAnomalous [
	^ self flags notEmpty
]

{ #category : 'accessing' }
GcVocabToken >> mergeRank [
	"The BPE merge rank at which this token's string was first formed (DW-18), or nil for a base byte / when no merge list is attached."
	^ mergeRank
]

{ #category : 'accessing' }
GcVocabToken >> mergeRank: anIntegerOrNil [
	mergeRank := anIntegerOrNil
]

{ #category : 'printing' }
GcVocabToken >> printOn: aStream [
	aStream
		nextPutAll: 'token ';
		print: self tokenId;
		nextPutAll: ' ';
		print: self text;
		nextPutAll: ' [';
		nextPutAll: self flagsString;
		nextPutAll: ']'
]

{ #category : 'accessing' }
GcVocabToken >> text [
	^ text
]

{ #category : 'accessing' }
GcVocabToken >> text: aString [
	text := aString
]

{ #category : 'accessing' }
GcVocabToken >> tokenId [
	^ tokenId
]

{ #category : 'accessing' }
GcVocabToken >> tokenId: anInteger [
	tokenId := anInteger
]
