"
An ordered group of GcLayers for one model: an embeddings band, the transformer layers in ascending depth, then a head/final band. Built by GcTensorGroup>>layers. The Layers view answers 'how is tensor mass distributed across depth, and where do the non-layer bands sit?'. (Per-layer metric curves with a regularity band are DW-17.)
"
Class {
	#name : 'GcLayerGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'gt - views' }
GcLayerGroup >> gtLayersFor: aView [
	"How much tensor mass lives at each depth? Bands (embeddings, head/final) sit at the ends; click a row to open that layer."
	<gtView>
	^ aView columnedList
		title: 'Layers';
		priority: 5;
		items: [ self items ];
		column: 'Layer' text: [ :layer | layer label ];
		column: 'Tensors' text: [ :layer | layer tensors size printString ];
		column: 'Params' text: [ :layer | layer totalParams printString ];
		send: [ :layer | layer ]
]
