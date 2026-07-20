"
A group of GcFindings. Signature view: status board, replication counts, campaign-wide correction state.
"
Class {
	#name : 'GcFindingGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'gt - views' }
GcFindingGroup >> gtStatusBoardFor: aView [
	"Campaign status board: how many findings sit at each status? Grouped counts, most populous first; click a row to open that status's findings. Empty-safe."
	<gtView>
	^ aView columnedList
		title: 'Status board';
		priority: 5;
		items: [ ((self groupedBy: [ :f | f status ]) associations
			asSortedCollection: [ :a :b | a value size > b value size ]) asArray ];
		column: 'Status' text: [ :assoc | assoc key isNil ifTrue: [ '(none)' ] ifFalse: [ assoc key asString ] ];
		column: 'Findings' text: [ :assoc | assoc value size printString ];
		send: [ :assoc | assoc value ]
]
