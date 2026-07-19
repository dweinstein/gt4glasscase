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

{ #category : 'views' }
GcGroupComparison >> gtSideBySideFor: aView [
	<gtView>
	"What differs between these two groups - membership and statistics, side by side?"
	^ aView columnedList
		title: 'Side by side';
		priority: 2;
		items: [ self sideBySideRows ];
		column: 'Facet' text: [ :row | row at: 1 ];
		column: 'Left' text: [ :row | row at: 2 ];
		column: 'Right' text: [ :row | row at: 3 ];
		column: 'Delta' text: [ :row | row at: 4 ];
		send: [ :row | row at: 5 ]
]

{ #category : 'gt actions' }
GcGroupComparison >> gtSwapSidesActionFor: anAction [
	<gtAction>
	^ anAction button
		tooltip: 'Open the mirror comparison with left and right swapped';
		priority: 20;
		icon: BrGlamorousVectorIcons refresh;
		action: [ :aButton |
			aButton phlow spawnObject: (GcGroupComparison left: right right: left) ]
]

{ #category : 'views' }
GcGroupComparison >> gtTwinCheckFor: aView [
	<gtView>
	"Do these artifacts really share one structural skeleton - same tensor set, same shapes - so a behavioral diff can be attributed to precision alone?"
	self isTensorComparison ifFalse: [ ^ aView empty ].
	^ aView columnedList
		title: 'Twin check';
		priority: 3;
		items: [ { { #verdict. self twinCheckVerdict. ''. ''. self } } , self twinCheckRows ];
		column: 'Status' text: [ :row | (row at: 1) asString ];
		column: 'Tensor' text: [ :row | row at: 2 ];
		column: 'Left' text: [ :row | row at: 3 ];
		column: 'Right' text: [ :row | row at: 4 ];
		send: [ :row | row at: 5 ]
]

{ #category : 'querying' }
GcGroupComparison >> inBoth [
	^ left items select: [ :each | right includes: each ]
]

{ #category : 'twin check' }
GcGroupComparison >> isTensorComparison [
	^ (left isKindOf: GcTensorGroup) and: [ right isKindOf: GcTensorGroup ]
]

{ #category : 'accessing' }
GcGroupComparison >> left [
	^ left
]

{ #category : 'accessing' }
GcGroupComparison >> left: aGroup [
	left := aGroup
]

{ #category : 'comparing' }
GcGroupComparison >> leftOnlyGroup [
	^ left withItems: self onlyInLeft derivedBy: #onlyInLeft
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

{ #category : 'comparing' }
GcGroupComparison >> rightOnlyGroup [
	^ right withItems: self onlyInRight derivedBy: #onlyInRight
]

{ #category : 'comparing' }
GcGroupComparison >> sharedGroup [
	^ left withItems: self inBoth derivedBy: #inBoth
]

{ #category : 'comparing' }
GcGroupComparison >> sideBySideRows [
	| rows leftStats rightStats keys |
	rows := OrderedCollection new.
	rows add: (Array
		with: 'Items'
		with: left size displayString
		with: right size displayString
		with: (right size - left size) displayString
		with: self).
	rows add: (Array
		with: 'Only in left'
		with: self onlyInLeft size displayString
		with: ''
		with: ''
		with: self leftOnlyGroup).
	rows add: (Array
		with: 'Only in right'
		with: ''
		with: self onlyInRight size displayString
		with: ''
		with: self rightOnlyGroup).
	rows add: (Array
		with: 'Shared'
		with: self inBoth size displayString
		with: self inBoth size displayString
		with: ''
		with: self sharedGroup).
	leftStats := left statistics.
	rightStats := right statistics.
	keys := (leftStats keys asSet
		addAll: rightStats keys;
		yourself) asSortedCollection.
	keys do: [ :key |
		key = #count ifFalse: [
			| lv rv deltaText |
			lv := leftStats at: key ifAbsent: [ nil ].
			rv := rightStats at: key ifAbsent: [ nil ].
			deltaText := (lv isNumber and: [ rv isNumber ])
				ifTrue: [ (rv - lv) displayString ]
				ifFalse: [ '' ].
			rows add: (Array
				with: key displayString
				with: (lv isNil ifTrue: [ '-' ] ifFalse: [ lv displayString ])
				with: (rv isNil ifTrue: [ '-' ] ifFalse: [ rv displayString ])
				with: deltaText
				with: left) ] ].
	^ rows asArray
]

{ #category : 'twin check' }
GcGroupComparison >> twinCheckRows [
	| leftByName rightByName names rank rows |
	leftByName := Dictionary new.
	left items do: [ :each | leftByName at: each name put: each ].
	rightByName := Dictionary new.
	right items do: [ :each | rightByName at: each name put: each ].
	names := leftByName keys asOrderedCollection.
	names addAll: rightByName keys.
	names := names asSet asSortedCollection asOrderedCollection.
	rank := Dictionary new.
	rank
		at: #onlyLeft put: 1;
		at: #onlyRight put: 2;
		at: #shapeMismatch put: 3;
		at: #dtypeShift put: 4;
		at: #match put: 5.
	rows := names collect: [ :name |
		| leftRef rightRef status leftDescription rightDescription payload |
		leftRef := leftByName at: name ifAbsent: [ nil ].
		rightRef := rightByName at: name ifAbsent: [ nil ].
		leftDescription := leftRef ifNil: [ '-' ] ifNotNil: [ leftRef shape printString , ' ' , leftRef dtype asString ].
		rightDescription := rightRef ifNil: [ '-' ] ifNotNil: [ rightRef shape printString , ' ' , rightRef dtype asString ].
		status := leftRef isNil
			ifTrue: [ #onlyRight ]
			ifFalse: [
				rightRef isNil
					ifTrue: [ #onlyLeft ]
					ifFalse: [
						(leftRef shape = rightRef shape)
							ifFalse: [ #shapeMismatch ]
							ifTrue: [ (leftRef dtype = rightRef dtype) ifTrue: [ #match ] ifFalse: [ #dtypeShift ] ] ] ].
		payload := leftRef ifNil: [ rightRef ] ifNotNil: [ leftRef ].
		{ status. name. leftDescription. rightDescription. payload } ].
	^ (rows asSortedCollection: [ :a :b |
		| ra rb |
		ra := rank at: (a at: 1).
		rb := rank at: (b at: 1).
		ra = rb
			ifTrue: [ (a at: 2) <= (b at: 2) ]
			ifFalse: [ ra < rb ] ]) asArray
]

{ #category : 'twin check' }
GcGroupComparison >> twinCheckVerdict [
	| rows onlyLeftCount onlyRightCount shapeMismatchCount problemsCount matchCount |
	rows := self twinCheckRows.
	onlyLeftCount := rows count: [ :row | (row at: 1) = #onlyLeft ].
	onlyRightCount := rows count: [ :row | (row at: 1) = #onlyRight ].
	shapeMismatchCount := rows count: [ :row | (row at: 1) = #shapeMismatch ].
	problemsCount := onlyLeftCount + onlyRightCount + shapeMismatchCount.
	problemsCount = 0
		ifTrue: [
			matchCount := rows count: [ :row | #(#match #dtypeShift) includes: (row at: 1) ].
			^ 'structural twins: ' , matchCount printString , ' tensors, same names and shapes' ].
	^ 'NOT twins: ' , onlyLeftCount printString , ' only-left, ' , onlyRightCount printString , ' only-right, ' , shapeMismatchCount printString , ' shape mismatches'
]
