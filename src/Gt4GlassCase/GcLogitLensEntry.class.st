"
One predicted token in a GcLogitLensStage: its 0-based token id, decoded text, raw logit and softmax probability, and rank (1 = most likely) at that depth.
"
Class {
	#name : 'GcLogitLensEntry',
	#superclass : 'Object',
	#instVars : [
		'rank',
		'tokenId',
		'tokenText',
		'logit',
		'prob'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcLogitLensEntry class >> rank: r tokenId: anId tokenText: aString logit: aLogit prob: aProb [
	^ self new
		rank: r;
		tokenId: anId;
		tokenText: aString;
		logit: aLogit;
		prob: aProb;
		yourself
]

{ #category : 'printing' }
GcLogitLensEntry >> displayToken [
	"The decoded token, bracketed so leading/trailing whitespace is visible."
	^ tokenText isNil
		ifTrue: [ '[?]' ]
		ifFalse: [ '[' , tokenText , ']' ]
]

{ #category : 'gt - views' }
GcLogitLensEntry >> gtSummaryFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Summary';
		priority: 10;
		items: [ { 'Rank' -> self rank. 'Token id' -> self tokenId. 'Token' -> self displayToken. 'Logit' -> self logitString. 'Probability' -> self probString } ];
		column: 'Field' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value asString ];
		send: [ :assoc | self ]
]

{ #category : 'accessing' }
GcLogitLensEntry >> logit [
	^ logit
]

{ #category : 'accessing' }
GcLogitLensEntry >> logit: aNumber [
	logit := aNumber
]

{ #category : 'printing' }
GcLogitLensEntry >> logitString [
	^ logit isNil ifTrue: [ '' ] ifFalse: [ logit printShowingDecimalPlaces: 3 ]
]

{ #category : 'printing' }
GcLogitLensEntry >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: ' '; nextPutAll: self displayToken; nextPutAll: ' id='; print: tokenId
]

{ #category : 'accessing' }
GcLogitLensEntry >> prob [
	^ prob
]

{ #category : 'accessing' }
GcLogitLensEntry >> prob: aNumber [
	prob := aNumber
]

{ #category : 'printing' }
GcLogitLensEntry >> probString [
	^ prob isNil ifTrue: [ '' ] ifFalse: [ prob printShowingDecimalPlaces: 4 ]
]

{ #category : 'accessing' }
GcLogitLensEntry >> rank [
	^ rank
]

{ #category : 'accessing' }
GcLogitLensEntry >> rank: anInteger [
	rank := anInteger
]

{ #category : 'accessing' }
GcLogitLensEntry >> tokenId [
	^ tokenId
]

{ #category : 'accessing' }
GcLogitLensEntry >> tokenId: anInteger [
	tokenId := anInteger
]

{ #category : 'accessing' }
GcLogitLensEntry >> tokenText [
	^ tokenText
]

{ #category : 'accessing' }
GcLogitLensEntry >> tokenText: aString [
	tokenText := aString
]
