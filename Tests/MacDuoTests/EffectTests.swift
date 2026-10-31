import Foundation
import ImageIO
import Metal
import Testing
@testable import MacDuo

struct EffectTests {
    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "Metal device required")) func shaderCompilesOnGPU() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: DepthShaders.source, options: nil)
        #expect(library.makeFunction(name: "depthFragment") != nil)
    }

    @Test func progressNeverSendsInvalidValuesToGPU() {
        #expect(EffectStyle.progress(.nan) == 0)
        #expect(EffectStyle.progress(.infinity) == 0)
        #expect(EffectStyle.progress(-1) == 0)
        #expect(EffectStyle.progress(2) == 1)
        #expect(EffectStyle.progress(0.5) == 0.5)
    }
}

struct EffectPixelTests {
    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "Metal device required")) func variantsStartClearAndHaveDistinctMidpoints() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let library = try device.makeLibrary(source: DepthShaders.source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "depthVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "depthFragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.vertexFunction = library.makeFunction(name: "glassVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "glassFragment")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        let glassPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.vertexFunction = library.makeFunction(name: "cardVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "cardFragment")
        let cardPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let cardVertices = CardDeckMesh.vertices(aspect: 1)
        let cardBuffer = try #require(cardVertices.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) })
        let rearVertices = cardVertices.filter { $0.motion.z > 0 }
        let rearBuffer = try #require(rearVertices.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) })
        let atlas = try #require(CardArtwork.makeAtlas())
        let atlasDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: atlas.width, height: atlas.height, mipmapped: false)
        atlasDescriptor.storageMode = .shared
        atlasDescriptor.usage = .shaderRead
        let atlasTexture = try #require(device.makeTexture(descriptor: atlasDescriptor))
        let atlasData = try #require(atlas.dataProvider?.data)
        atlasTexture.replace(region: MTLRegionMake2D(0, 0, atlas.width, atlas.height), mipmapLevel: 0, withBytes: CFDataGetBytePtr(atlasData)!, bytesPerRow: atlas.bytesPerRow)
        let back = try #require(CardBackArtwork.makeImage())
        let backDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: back.width, height: back.height, mipmapped: false)
        backDescriptor.storageMode = .shared
        backDescriptor.usage = .shaderRead
        let backTexture = try #require(device.makeTexture(descriptor: backDescriptor))
        let backData = try #require(back.dataProvider?.data)
        backTexture.replace(region: MTLRegionMake2D(0, 0, back.width, back.height), mipmapLevel: 0, withBytes: CFDataGetBytePtr(backData)!, bytesPerRow: back.bytesPerRow)
        var noteTextures: [EffectStyle: (MTLTexture, MTLTexture)] = [:]
        for style in [EffectStyle.rubles, .dollars] {
            let currency = try #require(style.banknoteCurrency)
            var textures: [MTLTexture] = []
            for reverse in [false, true] {
                let image = try #require(BanknoteArtwork.makeImage(currency: currency, reverse: reverse))
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: image.width, height: image.height, mipmapped: false)
                descriptor.storageMode = .shared; descriptor.usage = .shaderRead
                let texture = try #require(device.makeTexture(descriptor: descriptor))
                let data = try #require(image.dataProvider?.data)
                texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0, withBytes: CFDataGetBytePtr(data)!, bytesPerRow: image.bytesPerRow)
                textures.append(texture)
            }
            noteTextures[style] = (textures[0], textures[1])
        }
        let noteVertices = CardDeckMesh.vertices(aspect: 1, columns: 8, rows: 6)
        let noteBuffer = try #require(noteVertices.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) })
        let rearNotes = noteVertices.filter { $0.motion.z > 0 }
        let rearNoteBuffer = try #require(rearNotes.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) })
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        let depthState = try #require(device.makeDepthStencilState(descriptor: depthDescriptor))
        let vertices = GlassFracture.vertices(aspect: 1)
        let glassBuffer = try #require(vertices.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) })
        let exportDirectory = ProcessInfo.processInfo.environment["STIX_GLASS_TEST_FRAMES"]
        let size = exportDirectory == nil ? 64 : 512
        let sourceDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: true)
        sourceDescriptor.usage = [.shaderRead]
        sourceDescriptor.storageMode = .shared
        let source = try #require(device.makeTexture(descriptor: sourceDescriptor))
        let alternateSource = try #require(device.makeTexture(descriptor: sourceDescriptor))
        var alternatePixels = [UInt8](repeating: 255, count: size * size * 4)
        for i in stride(from: 0, to: alternatePixels.count, by: 4) {
            alternatePixels[i] = 20; alternatePixels[i + 1] = 90; alternatePixels[i + 2] = 180
        }
        alternatePixels.withUnsafeBytes { alternateSource.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: size * 4) }
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let i = (y * size + x) * 4
                pixels[i] = UInt8(x * 255 / (size - 1))
                pixels[i + 1] = UInt8(y * 255 / (size - 1))
                pixels[i + 2] = (x / 4 + y / 4) % 2 == 0 ? 255 : 0
            }
        }
        pixels.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: size * 4) }
        let mipCommand = try #require(queue.makeCommandBuffer())
        let blit = try #require(mipCommand.makeBlitCommandEncoder())
        blit.generateMipmaps(for: source)
        blit.endEncoding()
        mipCommand.commit()
        mipCommand.waitUntilCompleted()

        func render(_ style: EffectStyle, _ progress: Float, blackout: Bool = false, rearOnly: Bool = false, changedDesktop: Bool = false) throws -> [UInt8] {
            let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
            outputDescriptor.storageMode = .shared
            outputDescriptor.usage = [.renderTarget]
            let output = try #require(device.makeTexture(descriptor: outputDescriptor))
            // Same float4 ABI as DepthRenderer; an incorrect layout breaks this endpoint test.
            var uniforms: [SIMD4<Float>] = [
                SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0),
                SIMD4(Float(size), Float(size), 0, 0), SIMD4(Float(size), Float(size), 100, 0),
                SIMD4(0, 0, 1, 6), SIMD4(0, 0, 1, 0), SIMD4(Float(style.rawValue), progress, blackout ? 1 : 0, 0)
            ]
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = output
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            let isMesh = style == .shatter || style.isFlyingPaper
            if isMesh {
                let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: size, height: size, mipmapped: false)
                depthTextureDescriptor.storageMode = .private
                depthTextureDescriptor.usage = .renderTarget
                let depthTexture = try #require(device.makeTexture(descriptor: depthTextureDescriptor))
                pass.depthAttachment.texture = depthTexture
                pass.depthAttachment.loadAction = .clear
                pass.depthAttachment.storeAction = .dontCare
                pass.depthAttachment.clearDepth = 1
            }
            let command = try #require(queue.makeCommandBuffer())
            let encoder = try #require(command.makeRenderCommandEncoder(descriptor: pass))
            encoder.setRenderPipelineState(style.isFlyingPaper ? cardPipeline : style == .shatter ? glassPipeline : pipeline)
            if isMesh {
                encoder.setDepthStencilState(depthState)
                encoder.setVertexBuffer(style.banknoteCurrency != nil ? (rearOnly ? rearNoteBuffer : noteBuffer) : style == .cards ? (rearOnly ? rearBuffer : cardBuffer) : glassBuffer, offset: 0, index: 0)
                uniforms.withUnsafeMutableBytes { encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 1) }
            }
            uniforms.withUnsafeMutableBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0) }
            encoder.setFragmentTexture(changedDesktop ? alternateSource : source, index: 0)
            if style == .cards {
                encoder.setFragmentTexture(atlasTexture, index: 1)
                encoder.setFragmentTexture(backTexture, index: 2)
            }
            if let note = noteTextures[style] {
                encoder.setFragmentTexture(note.0, index: 1)
                encoder.setFragmentTexture(note.1, index: 2)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: style.banknoteCurrency != nil ? (rearOnly ? rearNotes.count : noteVertices.count) : style == .cards ? (rearOnly ? rearVertices.count : cardVertices.count) : style == .shatter ? vertices.count : 3)
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted()
            #expect(command.status == .completed)
            var result = pixels
            result.withUnsafeMutableBytes { output.getBytes($0.baseAddress!, bytesPerRow: size * 4, from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0) }
            return result
        }
        if let exportDirectory {
            try FileManager.default.createDirectory(atPath: exportDirectory, withIntermediateDirectories: true)
            for style in [EffectStyle.shatter, .cards, .paintRoller, .rubles, .dollars] {
                for (index, progress) in [Float(0), 0.12, 0.26, 0.43, 0.60, 0.76].enumerated() {
                    let bytes = try render(style, progress)
                    let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
                    let image = try #require(CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
                    let name = style == .cards ? "cards" : style == .paintRoller ? "roller" : style == .rubles ? "rubles" : style == .dollars ? "dollars" : "glass"
                    let url = URL(fileURLWithPath: exportDirectory).appendingPathComponent("\(name)-\(index).png")
                    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                    CGImageDestinationAddImage(destination, image, nil)
                    #expect(CGImageDestinationFinalize(destination))
                }
            }
            for style in [EffectStyle.rubles, .dollars] {
                for reverse in [false, true] {
                    let currency = try #require(style.banknoteCurrency)
                    let image = try #require(BanknoteArtwork.makeImage(currency: currency, reverse: reverse))
                    let name = style == .rubles ? "rubles" : "dollars"
                    let url = URL(fileURLWithPath: exportDirectory).appendingPathComponent("\(name)-\(reverse ? "back" : "front").png")
                    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                    CGImageDestinationAddImage(destination, image, nil)
                    #expect(CGImageDestinationFinalize(destination))
                }
            }
            let backURL = URL(fileURLWithPath: exportDirectory).appendingPathComponent("stix-card-back.png")
            let backDestination = try #require(CGImageDestinationCreateWithURL(backURL as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(backDestination, back, nil)
            #expect(CGImageDestinationFinalize(backDestination))
            let atlasURL = URL(fileURLWithPath: exportDirectory).appendingPathComponent("card-faces.png")
            let atlasDestination = try #require(CGImageDestinationCreateWithURL(atlasURL as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(atlasDestination, atlas, nil)
            #expect(CGImageDestinationFinalize(atlasDestination))
        }
        for style in EffectStyle.allCases {
            let black = try render(style, 1, blackout: true)
            #expect(black.enumerated().allSatisfy { $0.offset % 4 == 3 ? $0.element == 255 : $0.element == 0 }, "Manual effect must end fully black: \(style.title)")
        }
        #expect(try render(.cards, 0) != render(.cards, 0, changedDesktop: true))
        for phase: Float in [0, 0.3, 0.5] {
            let ordinaryCards = try render(.cards, phase, rearOnly: true)
            let differentScreen = try render(.cards, phase, rearOnly: true, changedDesktop: true)
            #expect(ordinaryCards == differentScreen, "Additional cards must not sample any desktop pixels")
        }
        for style in [EffectStyle.rubles, .dollars] {
            #expect(try render(style, 0) != render(style, 0, changedDesktop: true))
            for phase: Float in [0, 0.3, 0.5] {
                #expect(try render(style, phase, rearOnly: true) == render(style, phase, rearOnly: true, changedDesktop: true))
            }
        }
        let flyingCards = try render(.cards, 0.43)
        let visibleCards = stride(from: 0, to: flyingCards.count, by: 4).filter {
            flyingCards[$0] > 8 || flyingCards[$0 + 1] > 8 || flyingCards[$0 + 2] > 8
        }.count
        #expect(visibleCards > size * size / 10, "Cards must remain visibly in flight during the middle of the effect")
        #expect(visibleCards < size * size * 95 / 100, "Cards must separate, exposing space behind them")
        let lateCards = try render(.cards, 0.88)
        let lateVisible = stride(from: 0, to: lateCards.count, by: 4).filter {
            lateCards[$0] > 8 || lateCards[$0 + 1] > 8 || lateCards[$0 + 2] > 8
        }.count
        #expect(lateVisible > size * size / 100, "Staggered cards must keep flying near the end of the unchanged duration")
        let untouchedDesktop = try render(.original, 0)
        // Each completed horizontal pass must leave exactly one more black band.
        for (phase, paintedRows) in [(Float(0.32), 1), (Float(0.65), 2)] {
            let painted = try render(.paintRoller, phase)
            for band in 0..<3 {
                let x = size / 2, y = (2 * band + 1) * size / 6
                let pixel = (y * size + x) * 4
                let isBlack = painted[pixel..<pixel + 3].allSatisfy { $0 == 0 }
                #expect(isBlack == (band < paintedRows), "Paint must accumulate in three passes without fading the untouched desktop")
                if band >= paintedRows {
                    #expect(Array(painted[pixel..<pixel + 4]) == Array(untouchedDesktop[pixel..<pixel + 4]))
                }
            }
        }
        let fullPaint = try render(.paintRoller, 1)
        #expect(fullPaint.enumerated().allSatisfy { $0.offset % 4 == 3 ? $0.element == 255 : $0.element == 0 })
        #expect(EffectStyle.paintRoller.manualDuration == 4.2)
        let reference = try render(.original, 0)
        let cracking = try render(.shatter, 0.15)
        #expect(cracking != reference)
        #expect(cracking.enumerated().contains { $0.offset % 4 != 3 && $0.element > 0 })
        let falling = try render(.shatter, 0.8)
        #expect(falling != cracking)
        var midpoints: [[UInt8]] = []
        for style in EffectStyle.allCases where style != .original {
            #expect(try render(style, 0) == reference, "Opening must return to a clear desktop: \(style.title)")
            let middle = try render(style, 0.55)
            #expect(middle != reference)
            #expect(!midpoints.contains(middle))
            midpoints.append(middle)
            let end = try render(style, 1)
            #expect(end.enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 255 })
        }
    }
}
