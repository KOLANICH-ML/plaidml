// RUN: pmlc-opt \
// RUN:   -tile-compute-bounds \
// RUN:   -convert-tile-to-linalg \
// RUN:   -convert-linalg-to-pxa \
// RUN:   -pxa-normalize \
// RUN:   -canonicalize \
// RUN:   -pxa-fusion="avoid-reduction-indexes=false" \
// RUN:   -pxa-normalize \
// RUN:   -canonicalize \
// RUN:   -pxa-dataflow-opt \
// RUN:   -canonicalize \
// RUN:   -pxa-localize \
// RUN:   -pxa-resize-tmps \
// RUN:   -canonicalize \
// RUN:   %s | FileCheck %s

#map0 = affine_map<(d0, d1, d2, d3, d4) -> (d0, d1, d2, d3)>
#map1 = affine_map<(d0, d1, d2, d3, d4) -> (d0, d1, d2, d4)>

func @grn(%arg0: tensor<1x224x128x24xf16>) -> tensor<1x224x128x24xf16> {
  %cst = tile.constant(1.000000e-05 : f64) : tensor<f16>
  %cst_0 = tile.constant(0.000000e+00 : f64) : tensor<f16>
  %cst_1 = tile.constant(1.000000e+00 : f64) : tensor<f16>
  %0 = tile.mul %arg0, %arg0 : (tensor<1x224x128x24xf16>, tensor<1x224x128x24xf16>) -> tensor<1x224x128x24xf16>
  %1 = tile.contract add, none, %cst_0, %0 {sink = #map0, srcs = [#map1]} : tensor<f16>, tensor<1x224x128x24xf16> -> tensor<1x224x128x1xf16>
  %2 = tile.add %1, %cst_1 : (tensor<1x224x128x1xf16>, tensor<f16>) -> tensor<1x224x128x1xf16>
  %3 = tile.sqrt %2 : (tensor<1x224x128x1xf16>) -> tensor<1x224x128x1xf16>
  %4 = tile.cmp_lt %3, %cst : (tensor<1x224x128x1xf16>, tensor<f16>) -> tensor<1x224x128x1xi1>
  %5 = tile.select %4, %cst, %3 : (tensor<1x224x128x1xi1>, tensor<f16>, tensor<1x224x128x1xf16>) -> tensor<1x224x128x1xf16>
  %6 = tile.div %arg0, %5 : (tensor<1x224x128x24xf16>, tensor<1x224x128x1xf16>) -> tensor<1x224x128x24xf16>
  return %6 : tensor<1x224x128x24xf16>
}

// CHECK: func @grn(%[[in:.*]]: memref<1x224x128x24xf16>, %[[out:.*]]: memref<1x224x128x24xf16>) -> memref<1x224x128x24xf16>
// CHECK-DAG:   %[[epsilon:.*]] = arith.constant 1.001360e-05 : f16
// CHECK-DAG:   %[[zero:.*]] = arith.constant 0.000000e+00 : f16
// CHECK-DAG:   %[[one:.*]] = arith.constant 1.000000e+00 : f16
// CHECK-DAG:   %[[zeroI:.*]] = arith.constant 0 : index
// CHECK:   %[[P0:.*]] = affine.parallel (%[[i:.*]], %[[j:.*]]) = (0, 0) to (224, 128) reduce ("assign") -> (memref<1x224x128x24xf16>)
// CHECK:     %[[T0:.*]] = memref.alloc() : memref<1x1x1x1xf16>
// CHECK:     %[[T1:.*]] = pxa.reduce assign %[[zero]], %[[T0]][0, 0, 0, 0] : memref<1x1x1x1xf16>
// CHECK:     %[[P1:.*]] = affine.parallel (%[[k:.*]]) = (0) to (24) reduce ("assign") -> (memref<1x1x1x1xf16>)
// CHECK:       %[[X0:.*]] = pxa.load %[[in]][%[[zeroI]], %[[i]], %[[j]], %[[k]]] : memref<1x224x128x24xf16>
// CHECK:       %[[X1:.*]] = pxa.load %[[in]][%[[zeroI]], %[[i]], %[[j]], %[[k]]] : memref<1x224x128x24xf16>
// CHECK:       %[[X2:.*]] = arith.mulf %[[X0]], %[[X1]] : f16
// CHECK:       %[[X3:.*]] = pxa.reduce addf %[[X2]], %[[T1]][0, 0, 0, 0] : memref<1x1x1x1xf16>
// CHECK:       affine.yield %[[X3]] : memref<1x1x1x1xf16>
// CHECK:     %[[X5:.*]] = pxa.load %[[P1]][0, 0, 0, 0] : memref<1x1x1x1xf16>
// CHECK:     %[[X6:.*]] = arith.addf %[[X5]], %[[one]] : f16
// CHECK:     %[[X7:.*]] = math.sqrt %[[X6]] : f16
// CHECK:     %[[X8:.*]] = arith.cmpf olt, %[[X7]], %[[epsilon]] : f16
// CHECK:     %[[X9:.*]] = arith.select %[[X8]], %[[epsilon]], %[[X7]] : f16
// CHECK:     %[[P1:.*]] = affine.parallel (%[[k:.*]]) = (0) to (24) reduce ("assign") -> (memref<1x224x128x24xf16>)
// CHECK:       %[[X11:.*]] = pxa.load %[[in]][%[[zeroI]], %[[i]], %[[j]], %[[k]]] : memref<1x224x128x24xf16>
// CHECK:       %[[X12:.*]] = arith.divf %[[X11]], %[[X9]] : f16
// CHECK:       %[[X13:.*]] = pxa.reduce assign %[[X12]], %[[out]][%[[zeroI]], %[[i]], %[[j]], %[[k]]] : memref<1x224x128x24xf16>
// CHECK:       affine.yield %[[X13]] : memref<1x224x128x24xf16>
// CHECK:     affine.yield %[[P1]] : memref<1x224x128x24xf16>
// CHECK:   return %[[P0]] : memref<1x224x128x24xf16>
