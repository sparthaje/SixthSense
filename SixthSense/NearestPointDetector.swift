//
//  DBScan.swift
//  SixthSense
//
//  Created by Srikar Gouru on 3/23/24.
//

import Foundation
import KDTree

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
