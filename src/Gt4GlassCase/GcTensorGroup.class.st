"
A group of GcTensorRefs. Signature views: shape table, aggregate distribution, spectrum overlay, delta heatmap.
"
Class {
	#name : 'GcTensorGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'grouping' }
GcTensorGroup >> byLayer [
	^ self partitionBy: [ :t | t layerIndex ]
]

{ #category : 'grouping' }
GcTensorGroup >> byModule [
	^ self partitionBy: [ :t | t module ]
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
