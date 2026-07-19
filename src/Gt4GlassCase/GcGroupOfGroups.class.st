"
A group whose items are themselves groups (the result of partitionBy:). Itself a group with its own views, enabling recursive drill-down.
"
Class {
	#name : 'GcGroupOfGroups',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'small multiples' }
GcGroupOfGroups >> defaultCohortStencil [
	^ GcCohortStencil default
]

{ #category : 'views' }
GcGroupOfGroups >> gtSmallMultiplesFor: aView [
	<gtView>
	"Which cohort breaks the visual texture of its siblings?"
	^ self smallMultiplesViewFor: aView stencil: self defaultCohortStencil
]

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

{ #category : 'small multiples' }
GcGroupOfGroups >> smallMultiplesViewFor: aView stencil: aStencil [
	| context |
	context := aStencil contextFor: self.
	^ aView mondrian
		title: 'Small multiples';
		priority: 6;
		painting: [ :m |
			m nodes
				stencil: [ :childGroup | aStencil elementFor: childGroup context: context ];
				with: self items.
			m layout grid ]
]
