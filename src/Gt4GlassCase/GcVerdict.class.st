"
An oracle's judgment of a completion: pass/fail/error + score + rationale + confidence. Immutable (I7): re-judging with a new oracle version creates a new verdict so oracle drift stays visible.
"
Class {
	#name : 'GcVerdict',
	#superclass : 'Object',
	#instVars : [
		'completion',
		'oracle',
		'outcome',
		'score',
		'rationale',
		'confidence'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcVerdict class >> completion: aCompletion oracle: anOracle outcome: aSymbol [
	^ self new
		completion: aCompletion;
		oracle: anOracle;
		outcome: aSymbol;
		yourself
]

{ #category : 'accessing' }
GcVerdict >> completion [
	^ completion
]

{ #category : 'accessing' }
GcVerdict >> completion: aCompletion [
	completion := aCompletion
]

{ #category : 'accessing' }
GcVerdict >> confidence [
	^ confidence
]

{ #category : 'accessing' }
GcVerdict >> confidence: aNumber [
	confidence := aNumber
]

{ #category : 'testing' }
GcVerdict >> isPass [
	^ outcome = #pass
]

{ #category : 'accessing' }
GcVerdict >> oracle [
	^ oracle
]

{ #category : 'accessing' }
GcVerdict >> oracle: anOracle [
	oracle := anOracle
]

{ #category : 'accessing' }
GcVerdict >> outcome [
	^ outcome
]

{ #category : 'accessing' }
GcVerdict >> outcome: aSymbol [
	outcome := aSymbol
]

{ #category : 'printing' }
GcVerdict >> printOn: aStream [
	aStream nextPutAll: 'GcVerdict('.
	aStream nextPutAll: (outcome ifNil: [ '?' ]) asString.
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcVerdict >> rationale [
	^ rationale
]

{ #category : 'accessing' }
GcVerdict >> rationale: aString [
	rationale := aString
]

{ #category : 'accessing' }
GcVerdict >> score [
	^ score
]

{ #category : 'accessing' }
GcVerdict >> score: aNumber [
	score := aNumber
]
