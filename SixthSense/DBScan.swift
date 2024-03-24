//
//  DBScan.swift
//  SixthSense
//
//  Created by Srikar Gouru on 3/23/24.
//

import Foundation
import KDTree

//struct CustomPoint {
//    let x: Double
//    let y: Double
//    let z: Double
//}

func == (lhs: SIMD3<Double>, rhs: SIMD3<Double>) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
}

extension SIMD3<Double>: Equatable {}

extension SIMD3<Double>: KDTreePoint {
    public static var dimensions: Int = 3
    public func kdDimension(_ dimension: Int) -> Double {
        if dimension == 0 {
            return x
        }
        else if dimension == 1 {
            return y
        }
        return z
    }
    public func squaredDistance(to otherPoint: Self) -> Double {
        let dx = x - otherPoint.x
        let dy = y - otherPoint.y
        let dz = z - otherPoint.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
}

class NearestPointDetector {
    // Assume that points is sorted by distance, from closest to farthest.
    func getNearestPoint(points: [SIMD3<Double>], minPoints: Int, epsilon: Double) -> [SIMD3<Double>]? {
        var tree: KDTree<SIMD3<Double>> = KDTree(values: points)

        var cluster: [SIMD3<Double>] = []
        var i = 0
        for (index, point) in points.enumerated() {
            if i == 5 {
                break;
            }
            let neighbors: [SIMD3<Double>] = tree.elementsIn([(point.x - epsilon, point.x + epsilon),
                                                                  (point.y - epsilon, point.y + epsilon),
                                                                  (point.z - epsilon, point.z + epsilon)])

            if neighbors.count < minPoints {
                continue
            }
            cluster.append(point)
            i += 1;
        }

        return cluster
    }
}


class DBScan {
//    func clusterPoints(points: [SIMD3<Double>], minPoints: Int, epsilon: Double) -> [[SIMD3<Double>]] {
    func clusterPoints(points: [SIMD3<Double>], minPoints: Int, epsilon: Double) -> [Set<SIMD3<Double>>] {
        var tree: KDTree<SIMD3<Double>> = KDTree(values: points)

//        var clusters = [[SIMD3<Double>]]()
        var clusters: [Set<SIMD3<Double>>] = []
        var visited = Set<SIMD3<Double>>()
    
        for (index, point) in points.enumerated() {
            if visited.contains(point) { continue }
            visited.insert(point)
    
//            let neighbors = findNeighbors(points: points, point: point, epsilon: epsilon)
            let neighbors: [SIMD3<Double>] = tree.elementsIn([(point.x - epsilon, point.x + epsilon),
                                                                  (point.y - epsilon, point.y + epsilon),
                                                                  (point.z - epsilon, point.z + epsilon)])

            if neighbors.count < minPoints {
                continue
            }
    
//            var cluster = [SIMD3<Double>]()
            var cluster = Set<SIMD3<Double>>()
//            cluster.append(point)
            cluster.insert(point)

            
            for neighborPoint in neighbors {
                if !visited.contains(neighborPoint) {
                    visited.insert(neighborPoint)
                    //                    let neighborNeighbors = findNeighbors(points: points, point: neighborPoint, epsilon: epsilon)
                    let neighborNeighbors: [SIMD3<Double>] = tree.elementsIn([(neighborPoint.x - epsilon, neighborPoint.x + epsilon),
                                                                              (neighborPoint.y - epsilon, neighborPoint.y + epsilon),
                                                                              (neighborPoint.z - epsilon, neighborPoint.z + epsilon)])
                    
                    if neighborNeighbors.count >= minPoints {
                        //                        cluster.append(contentsOf: neighborNeighbors )
                        cluster.formUnion(neighborNeighbors)
                    }
                }
                //                if !cluster.contains(where: { $0 == neighborPoint }) {
                if !cluster.contains(neighborPoint) {
                    //                    cluster.append(neighborPoint)
                    cluster.insert(neighborPoint)
                }
            }
                
            clusters.append(cluster)
        }
             
        return clusters
    }
    
//    func findNeighbors(points: [vector_Double3], point: SIMD3<Double>, epsilon: Double) -> [Int] {
//        var neighbors = [Int]()
//        for (index, otherPoint) in points.enumerated() {
//            if distance(point, otherPoint) < epsilon {
//                neighbors.append(index)
//            }
//        }
//        return neighbors
//    }
}
