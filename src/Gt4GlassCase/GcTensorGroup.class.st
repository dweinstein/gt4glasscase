"
A group of GcTensorRefs. Signature views: shape table, aggregate distribution, spectrum overlay, delta heatmap.
"
Class {
	#name : 'GcTensorGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'converting' }
GcTensorGroup >> asTensorTree [
	"Build the tensor-name hierarchy (root GcTensorTreeNode) by splitting each tensor's dotted name."
	| root |
	root := GcTensorTreeNode named: '' path: ''.
	self items do: [ :aTensor |
		| node parts prefix |
		node := root.
		parts := aTensor name substrings: '.'.
		prefix := ''.
		parts doWithIndex: [ :seg :i |
			prefix := prefix isEmpty ifTrue: [ seg ] ifFalse: [ prefix, '.', seg ].
			i = parts size
				ifTrue: [ node addChild: (GcTensorTreeNode named: seg path: prefix tensor: aTensor) ]
				ifFalse: [ node := node childNamed: seg ifAbsentAddPath: prefix ] ] ].
	^ root
]

{ #category : 'grouping' }
GcTensorGroup >> byLayer [
	^ self partitionBy: [ :t | t layerIndex ]
]

{ #category : 'grouping' }
GcTensorGroup >> byModule [
	^ self partitionBy: [ :t | t module ]
]

{ #category : 'views' }
GcTensorGroup >> colorForBlock: aSymbol [
	aSymbol = #attention ifTrue: [ ^ Color r: 0.20 g: 0.45 b: 0.80 ].
	aSymbol = #mlp ifTrue: [ ^ Color r: 0.85 g: 0.45 b: 0.20 ].
	aSymbol = #embedding ifTrue: [ ^ Color r: 0.25 g: 0.65 b: 0.35 ].
	aSymbol = #norm ifTrue: [ ^ Color r: 0.60 g: 0.60 b: 0.62 ].
	^ Color gray
]

{ #category : 'views' }
GcTensorGroup >> gtByLayerFor: aView [
	"How does parameter mass vary with depth? Clicking a row opens that layer's tensor sub-group."
	<gtView>
	^ aView columnedList
		title: 'By layer';
		priority: 7;
		items: [ self layerSummaries ];
		column: 'Layer' text: [ :assoc | assoc key isNil ifTrue: [ '(non-layer)' ] ifFalse: [ assoc key printString ] ];
		column: 'Tensors' text: [ :assoc | assoc value size printString ];
		column: 'Params' text: [ :assoc | assoc value totalParams printString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'views' }
GcTensorGroup >> gtByModuleFor: aView [
	"How is parameter mass distributed across module types? Clicking a row opens that module's tensor sub-group."
	<gtView>
	^ aView columnedList
		title: 'By module';
		priority: 6;
		items: [ self moduleSummaries ];
		column: 'Module' text: [ :assoc | assoc key ];
		column: 'Tensors' text: [ :assoc | assoc value size printString ];
		column: 'Params' text: [ :assoc | assoc value totalParams printString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt search' }
GcTensorGroup >> gtSearchTensorsFor: aSearch [
	<gtSearch>
	^ aSearch list
		title: 'Tensors';
		priority: 10;
		items: [ self items ];
		itemName: [ :t | t name ];
		filterBySubstring
]

{ #category : 'views' }
GcTensorGroup >> gtShapeTableFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Tensors';
		priority: 5;
		items: [ self items ];
		column: 'Name' text: [ :t | t name ];
		column: 'Dtype' text: [ :t | t dtype asString ];
		column: 'Shape' text: [ :t | t shape printString ];
		column: 'Params' text: [ :t | t paramCount printString ];
		column: 'Bytes' text: [ :t | t byteSize printString ]
]

{ #category : 'views' }
GcTensorGroup >> gtSkylineFor: aView [
	"Every tensor as a box sized by parameter count and coloured by block (blue attention, orange mlp, green embedding, grey norm). A regular transformer is boringly uniform; an anomaly would break the texture. Click a box to inspect the tensor."
	<gtView>
	^ aView mondrian
		title: 'Skyline';
		priority: 9;
		painting: [ :m |
			m nodes
				stencil: [ :tensor |
					| side |
					side := ((tensor paramCount + 1) sqrt / 44) max: 4.
					BlElement new
						background: (self colorForBlock: tensor parsedName block);
						size: side @ side;
						yourself ];
				with: self items.
			m layout grid ]
]

{ #category : 'views' }
GcTensorGroup >> gtStatisticsFor: aView [
	"Summary metrics for this tensor group."
	<gtView>
	^ aView columnedList
		title: 'Statistics';
		priority: 8;
		items: [ (self statistics associations asSortedCollection: [ :a :b | a key < b key ]) asArray ];
		column: 'Metric' text: [ :assoc | assoc key asString ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'views' }
GcTensorGroup >> gtTreeFor: aView [
	"The tensor-name hierarchy (forwarded to the tree root)."
	<gtView>
	^ aView forward
		title: 'Tree';
		priority: 4;
		object: [ self asTensorTree ];
		view: #gtTreeFor:
]

{ #category : 'grouping' }
GcTensorGroup >> layerIndices [
	^ (((self collect: [ :t | t layerIndex ]) reject: [ :x | x isNil ]) asSet) asSortedCollection asArray
]

{ #category : 'views' }
GcTensorGroup >> layerSummaries [
	^ ((self groupedBy: [ :t | t layerIndex ]) associations
		asSortedCollection: [ :a :b | (a key ifNil: [ -1 ]) < (b key ifNil: [ -1 ]) ]) asArray
]

{ #category : 'views' }
GcTensorGroup >> moduleSummaries [
	^ ((self groupedBy: [ :t | t module ifNil: [ '(none)' ] ]) associations
		asSortedCollection: [ :a :b | a key < b key ]) asArray
]

{ #category : 'analyzing' }
GcTensorGroup >> statistics [
	^ (Dictionary new)
		at: #tensorCount put: self size;
		at: #totalParams put: self totalParams;
		at: #totalBytes put: self totalBytes;
		at: #modules put: self byModule size;
		yourself
]

{ #category : 'aggregating' }
GcTensorGroup >> totalBytes [
	^ self inject: 0 into: [ :sum :t | sum + t byteSize ]
]

{ #category : 'aggregating' }
GcTensorGroup >> totalParams [
	^ self inject: 0 into: [ :sum :t | sum + t paramCount ]
]
