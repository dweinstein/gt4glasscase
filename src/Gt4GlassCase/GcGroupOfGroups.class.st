"
A group whose items are themselves groups (the result of partitionBy:). Itself a group with its own views, enabling recursive drill-down.
"
Class {
	#name : 'GcGroupOfGroups',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'views' }
GcGroupOfGroups >> gtSubgroupsFor: aView [
	"What are the partitions, and how big is each?"
	<gtView>
	^ aView columnedList
		title: 'Subgroups';
		priority: 5;
		items: [ self items ];
		column: 'Group' text: [ :g | g printString ];
		column: 'Size' text: [ :g | g size printString ]
]
