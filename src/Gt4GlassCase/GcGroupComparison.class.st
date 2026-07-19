"
The result of GcGroup>>compareTo:: which items are in both groups, only in the left, or only in the right.
"
Class {
	#name : 'GcGroupComparison',
	#superclass : 'Object',
	#instVars : [
		'left',
		'right'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcGroupComparison class >> left: aGroup right: anotherGroup [
	^ self new
		left: aGroup;
		right: anotherGroup;
		yourself
]

{ #category : 'querying' }
GcGroupComparison >> inBoth [
	^ left items select: [ :each | right includes: each ]
]

{ #category : 'accessing' }
GcGroupComparison >> left [
	^ left
]

{ #category : 'accessing' }
GcGroupComparison >> left: aGroup [
	left := aGroup
]

{ #category : 'querying' }
GcGroupComparison >> onlyInLeft [
	^ left items reject: [ :each | right includes: each ]
]

{ #category : 'querying' }
GcGroupComparison >> onlyInRight [
	^ right items reject: [ :each | left includes: each ]
]

{ #category : 'printing' }
GcGroupComparison >> printOn: aStream [
	aStream nextPutAll: 'GcGroupComparison('.
	aStream print: self inBoth size.
	aStream nextPutAll: ' shared, '.
	aStream print: self onlyInLeft size.
	aStream nextPutAll: ' only-left, '.
	aStream print: self onlyInRight size.
	aStream nextPutAll: ' only-right)'
]

{ #category : 'accessing' }
GcGroupComparison >> right [
	^ right
]

{ #category : 'accessing' }
GcGroupComparison >> right: aGroup [
	right := aGroup
]
