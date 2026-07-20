"
A candidate trigger: a token, phrase, entity, formatting, or turn structure, plus where it is inserted (prefix/mid/suffix/system).
"
Class {
	#name : 'GcTrigger',
	#superclass : 'Object',
	#instVars : [
		'form',
		'content',
		'position'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTrigger class >> form: aFormSymbol content: anObject position: aPositionSymbol [
	^ self new form: aFormSymbol; content: anObject; position: aPositionSymbol; yourself
]

{ #category : 'accessing' }
GcTrigger >> content [
	^ content
]

{ #category : 'accessing' }
GcTrigger >> content: anObject [
	content := anObject
]

{ #category : 'accessing' }
GcTrigger >> form [
	^ form
]

{ #category : 'accessing' }
GcTrigger >> form: aSymbol [
	form := aSymbol
]

{ #category : 'accessing' }
GcTrigger >> position [
	^ position
]

{ #category : 'accessing' }
GcTrigger >> position: aSymbol [
	position := aSymbol
]

{ #category : 'printing' }
GcTrigger >> printOn: aStream [
	aStream nextPutAll: 'trigger '; print: form; nextPutAll: ' '; print: content; nextPutAll: ' @'; print: position
]
