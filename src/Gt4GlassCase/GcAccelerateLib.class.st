"
UFFI binding to the macOS Accelerate framework (vecLib/BLAS). Points UFFI at the system Accelerate umbrella framework so GcBlasBackend can ffiCall: cblas_sgemm. Instance-side macLibraryName (NOT macModuleName) is the UFFI convention for locating the dylib on macOS.
"
Class {
	#name : 'GcAccelerateLib',
	#superclass : 'FFILibrary',
	#category : 'Gt4GlassCase-Performance',
	#package : 'Gt4GlassCase',
	#tag : 'Performance'
}

{ #category : 'accessing' }
GcAccelerateLib >> macLibraryName [
	^ '/System/Library/Frameworks/Accelerate.framework/Accelerate'
]
