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

{ #category : 'grouping' }
GcTensorGroup >> layerIndices [
	^ (((self collect: [ :t | t layerIndex ]) reject: [ :x | x isNil ]) asSet) asSortedCollection asArray
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
