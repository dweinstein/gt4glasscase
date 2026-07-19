"
A single point in the hypercube: a set of axisName -> value bindings. Supports withoutAxis: (the basis of every divergence: variance along one axis with the rest held fixed), plus value equality and hashing so it can serve as a fast dictionary key at scale (I4).
"
Class {
	#name : 'GcCoordinate',
	#superclass : 'Object',
	#instVars : [
		'bindings'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'comparing' }
GcCoordinate >> = anObject [
	^ self class = anObject class
		and: [ bindings = anObject bindings ]
]

{ #category : 'accessing' }
GcCoordinate >> at: anAxisName [
	^ bindings at: anAxisName asSymbol
]

{ #category : 'building' }
GcCoordinate >> at: anAxisName put: aValue [
	bindings at: anAxisName asSymbol put: aValue.
	^ aValue
]

{ #category : 'accessing' }
GcCoordinate >> axes [
	^ bindings keys asSortedCollection asArray
]

{ #category : 'accessing' }
GcCoordinate >> bindings [
	^ bindings
]

{ #category : 'views' }
GcCoordinate >> gtBindingsFor: aView [
	"Where in the hypercube does this coordinate sit? Clicking a row sends the bound value."
	<gtView>
	^ aView columnedList
		title: 'Coordinate';
		priority: 1;
		items: [ self axes ];
		column: 'Axis' text: [ :axisName | axisName asString ];
		column: 'Value' text: [ :axisName | (self at: axisName) displayString ];
		send: [ :axisName | self at: axisName ]
]

{ #category : 'comparing' }
GcCoordinate >> hash [
	^ bindings hash
]

{ #category : 'initialization' }
GcCoordinate >> initialize [
	super initialize.
	bindings := Dictionary new
]

{ #category : 'printing' }
GcCoordinate >> printOn: aStream [
	aStream nextPutAll: 'GcCoordinate('.
	self axes
		do: [ :axisName |
			aStream nextPutAll: axisName asString.
			aStream nextPut: $=.
			aStream print: (bindings at: axisName) ]
		separatedBy: [ aStream nextPutAll: ', ' ].
	aStream nextPut: $)
]

{ #category : 'operations' }
GcCoordinate >> withoutAxis: anAxisName [
	"A copy of this coordinate with the given axis removed. The basis of a divergence: variance along one axis with all others held fixed."
	| copy |
	copy := self class new.
	bindings keysAndValuesDo: [ :k :v |
		k = anAxisName asSymbol ifFalse: [ copy at: k put: v ] ].
	^ copy
]
