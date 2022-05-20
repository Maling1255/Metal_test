//
//  Renderer.swift
//  MaLiang
//
//  Created by Harley-xk on 2020/11/4.
//

import Foundation
import MetalKit

class Renderer: NSObject {
    
    // 就好比电脑 GPU
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    weak var canvas: Canvas?
    
    init(delegateTo canvas: Canvas) throws {
        
        // 获取 设备 & 渲染队列
        guard let device = sharedDevice,
              let queue = device.makeCommandQueue() else {
            throw MLError.initializationError
        }
        self.device = device
        self.commandQueue = queue
        self.canvas = canvas
        
        super.init()
        canvas.delegate = self
        
        let backgroundColor = canvas.backgroundColor ?? .white
        let descriptor = canvas.currentRenderPassDescriptor
        descriptor?.colorAttachments[0].clearColor = backgroundColor.toClearColor()
        descriptor?.colorAttachments[0].loadAction = .load
        descriptor?.colorAttachments[0].storeAction = .store
    }
}

extension Renderer: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        
        // 1. 命令缓存区
        let buffer = commandQueue.makeCommandBuffer()
        
        //  渲染描述符
        guard let descriptor = view.currentRenderPassDescriptor else {
            return
        }
        // 2. 命令编码器
        let commandEncoder = buffer?.makeRenderCommandEncoder(descriptor: descriptor)
        
        var lines = canvas?.data.elements.compactMap { $0 as? LineStrip } ?? []
        if let current = canvas?.data.currentElement as? LineStrip {
            lines.append(current)
        }

        guard let target = canvas?.screenTarget else {
            return
        }
        
        for lineStrip in lines {

            guard let brush = lineStrip.brush ?? canvas?.defaultBrush else {
                continue
            }
            // 设置管道状态
            commandEncoder?.setRenderPipelineState(brush.pipelineState)

            if let vertex_buffer = lineStrip.retrieveBuffers(rotation: brush.rotation) {
                commandEncoder?.setVertexBuffer(vertex_buffer, offset: 0, index: 0)
                commandEncoder?.setVertexBuffer(target.uniform_buffer, offset: 0, index: 1)
                commandEncoder?.setVertexBuffer(target.transform_buffer, offset: 0, index: 2)
                if let texture = brush.texture {
                    commandEncoder?.setFragmentTexture(texture, index: 0)
                }
                commandEncoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: lineStrip.vertexCount)
            }
        }
        
        // 结束 编辑
        commandEncoder?.endEncoding()
        
        // 提交
        guard let drawable = view.currentDrawable else {
            return
        }
        buffer?.present(drawable)
        
        // 执行  (提交到GPU, 呈现显示效果)
        buffer?.commit()
    }
}
