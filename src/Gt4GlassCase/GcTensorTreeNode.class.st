"
One node in a model's tensor-name hierarchy (model -> layers -> 0 -> mlp -> down_proj -> weight), mirroring HuggingFace's file tree. An intermediate node has children and a nil tensor; a leaf node carries its GcTensorRef. Built by GcTensorGroup>>asTensorTree. Supports path-compression (single-child chains collapse for display, like HF).
"
Class {
	#name : 'GcTensorTreeNode',
	#superclass : 'Object',
	#instVars : [
		'segment',
		'path',
		'children',
		'tensor'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTensorTreeNode class >> named: aSegment path: aPath [
	^ self new segment: aSegment; path: aPath; yourself
]

{ #category : 'instance creation' }
GcTensorTreeNode class >> named: aSegment path: aPath tensor: aTensor [
	^ (self named: aSegment path: aPath) tensor: aTensor; yourself
]

{ #category : 'building' }
GcTensorTreeNode >> addChild: aNode [
	self children add: aNode.
	^ aNode
]

{ #category : 'converting' }
GcTensorTreeNode >> asGroup [
	"A GcTensorGroup of every tensor under this node -- reuses the group model so a subtree can be partitioned, sampled, skylined, compared."
	^ GcTensorGroup withAll: self tensors
]

{ #category : 'building' }
GcTensorTreeNode >> childNamed: aSegment ifAbsentAddPath: aPath [
	^ self children
		detect: [ :c | c segment = aSegment ]
		ifNone: [ self addChild: (self class named: aSegment path: aPath) ]
]

{ #category : 'accessing' }
GcTensorTreeNode >> children [
	^ children ifNil: [ children := OrderedCollection new ]
]

{ #category : 'compression' }
GcTensorTreeNode >> compressed [
	"Follow single-child, non-leaf chains and return the deepest such node (path compression, like HF)."
	^ (tensor isNil and: [ self children size = 1 ])
		ifTrue: [ self children anyOne compressed ]
		ifFalse: [ self ]
]

{ #category : 'compression' }
GcTensorTreeNode >> compressedSegment [
	"This node's segment extended through any single-child non-leaf chain, e.g. 'up_proj.weight'."
	^ (tensor isNil and: [ self children size = 1 ])
		ifTrue: [ segment, '.', self children anyOne compressedSegment ]
		ifFalse: [ segment ]
]

{ #category : 'displaying' }
GcTensorTreeNode >> displayLabel [
	"The full dotted path (HuggingFace-style), with a child count for interior nodes."
	| c |
	c := self compressed.
	^ c isLeaf
		ifTrue: [ c path ]
		ifFalse: [ c path, ' (', c children size printString, ')' ]
]

{ #category : 'views' }
GcTensorTreeNode >> gtTreeFor: aView [
	"The tensor-name hierarchy, HuggingFace-style: full dotted paths, numeric-sorted layers, child counts on interior nodes, and shape + precision on leaves. Click a leaf to inspect the tensor; click an interior node to get its subtree as a GcTensorGroup."
	<gtView>
	^ aView columnedTree
		title: 'Tree';
		priority: 2;
		items: [ self compressed sortedChildren ];
		children: [ :node | node compressed sortedChildren ];
		column: 'Tensors' text: [ :node | node displayLabel ];
		column: 'Shape' text: [ :node | node shapeText ];
		column: 'Precision' text: [ :node | node precisionText ];
		send: [ :node | node compressed isLeaf
			ifTrue: [ node compressed tensor ]
			ifFalse: [ node compressed asGroup ] ]
]

{ #category : 'initialization' }
GcTensorTreeNode >> initialize [
	super initialize.
	children := OrderedCollection new
]

{ #category : 'testing' }
GcTensorTreeNode >> isLeaf [
	^ tensor notNil
]

{ #category : 'sorting' }
GcTensorTreeNode >> isNumericSegment: aString [
	^ aString notEmpty and: [ aString allSatisfy: [ :c | c isDigit ] ]
]

{ #category : 'accessing' }
GcTensorTreeNode >> path [
	^ path
]

{ #category : 'accessing' }
GcTensorTreeNode >> path: aString [
	path := aString
]

{ #category : 'displaying' }
GcTensorTreeNode >> precisionText [
	^ self compressed tensor
		ifNil: [ '' ]
		ifNotNil: [ :t | t dtype ifNil: [ '' ] ifNotNil: [ :d | d asString asUppercase ] ]
]

{ #category : 'printing' }
GcTensorTreeNode >> printOn: aStream [
	aStream nextPutAll: 'GcTensorTreeNode('.
	aStream nextPutAll: ((path isNil or: [ path isEmpty ]) ifTrue: [ '<root>' ] ifFalse: [ path ]).
	aStream nextPutAll: ', '.
	aStream print: self tensorCount.
	aStream nextPutAll: ' tensors)'
]

{ #category : 'accessing' }
GcTensorTreeNode >> segment [
	^ segment
]

{ #category : 'accessing' }
GcTensorTreeNode >> segment: aString [
	segment := aString
]

{ #category : 'displaying' }
GcTensorTreeNode >> shapeText [
	^ self compressed tensor
		ifNil: [ '' ]
		ifNotNil: [ :t | t shape ifNil: [ '' ] ifNotNil: [ :s | s printString ] ]
]

{ #category : 'sorting' }
GcTensorTreeNode >> sortedChildren [
	^ (self children asSortedCollection: [ :x :y | x sortsBefore: y ]) asArray
]

{ #category : 'sorting' }
GcTensorTreeNode >> sortsBefore: anotherNode [
	"Numeric segments sort by integer value (so layer 2 precedes layer 10); everything else alphabetically."
	| a b |
	a := segment.
	b := anotherNode segment.
	((self isNumericSegment: a) and: [ self isNumericSegment: b ])
		ifTrue: [ ^ a asInteger < b asInteger ].
	^ a < b
]

{ #category : 'accessing' }
GcTensorTreeNode >> tensor [
	^ tensor
]

{ #category : 'accessing' }
GcTensorTreeNode >> tensor: aTensor [
	tensor := aTensor
]

{ #category : 'querying' }
GcTensorTreeNode >> tensorCount [
	^ self isLeaf
		ifTrue: [ 1 ]
		ifFalse: [ self children inject: 0 into: [ :sum :c | sum + c tensorCount ] ]
]

{ #category : 'querying' }
GcTensorTreeNode >> tensors [
	"All leaf tensors under this node."
	| acc |
	acc := OrderedCollection new.
	self tensorsInto: acc.
	^ acc
]

{ #category : 'querying' }
GcTensorTreeNode >> tensorsInto: aCollection [
	self isLeaf
		ifTrue: [ aCollection add: tensor ]
		ifFalse: [ self children do: [ :c | c tensorsInto: aCollection ] ]
]

{ #category : 'querying' }
GcTensorTreeNode >> totalParams [
	^ self isLeaf
		ifTrue: [ tensor paramCount ]
		ifFalse: [ self children inject: 0 into: [ :sum :c | sum + c totalParams ] ]
]
