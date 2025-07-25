// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import ArgumentParser
import Foundation
import Hummingbird

@main
struct CLI: AsyncParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    func run() async throws {
        let userStoreURL = appDataURL().appendingPathComponent("users.json")
        let recipeStoreURL = appDataURL().appendingPathComponent("recipes.json")
        
        let userStore = CodableUserStore(storeURL: userStoreURL)
        let recipeStore = CodableRecipeStore(storeURL: recipeStoreURL)
        
        let config = ApplicationConfiguration(address: .hostname(self.hostname, port: self.port), serverName: "Hummingbird")
        
       return try await AppComposer.execute(
            with: config,
            secretKey: "my secret key that should come from deployment environment",
            userStore: userStore,
            recipeStore: recipeStore
       ).runService()
    }
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    private func appDataURL() -> URL {
        cachesDirectory().appendingPathComponent("\(type(of: self))")
    }
}
