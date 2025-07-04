// © 2025  Cristian Felipe Patiño Rojas. Created on 21/6/25.

import Foundation
import Hummingbird
import JWTKit
import GenericAuth

public enum AppComposer {
    static public func execute(with configuration: ApplicationConfiguration, secretKey: HMACKey, userStore: UserStore, recipeStore: RecipeStore) async -> some ApplicationProtocol {
        
        let jwtKeyCollection = JWTKeyCollection()
        await jwtKeyCollection.add(
            hmac: secretKey,
            digestAlgorithm: .sha256,
            kid: JWKIdentifier("auth-jwt")
        )
        
        let tokenProvider = TokenProvider(kid: JWKIdentifier("auth-jwt"), jwtKeyCollection: jwtKeyCollection)
        let tokenVerifier = TokenVerifier(jwtKeyCollection: jwtKeyCollection)
        let passwordHasher = BCryptPasswordHasher()
        let passwordVerifier = BCryptPasswordVerifier()
        
        let emailValidator: EmailValidator = { _ in true }
        let passwordValidator: PasswordValidator = { _ in true }
        
    
        let registerController = RegisterController<UUID>(
            userMaker: userStore.createUser,
            userExists: userStore.findUser |>> isNotNil,
            emailValidator: emailValidator,
            passwordValidator: passwordValidator,
            tokenProvider: tokenProvider.execute,
            passwordHasher: passwordHasher.execute
        ) |> RegisterControllerAdapter.init
         
        let loginController = LoginController<UUID>(
            userFinder: userStore.findUser |>> UserMapper.map,
            emailValidator: emailValidator,
            passwordValidator: passwordValidator,
            tokenProvider: tokenProvider.execute,
            passwordVerifier: passwordVerifier.execute
        ) |> LoginControllerAdapter.init
        
        let recipesController = RecipesController(store: recipeStore, tokenVerifier: tokenVerifier.execute) |> RecipesControllerAdapter.init
        
        return Application(router: Router() .* { router in
            router.post("/register", use: registerController.handle)
            router.post("/login", use: loginController.handle)
            router.addRoutes(recipesController.endpoints, atPath: "/recipes")
        }, configuration: configuration )
    }
}


enum UserMapper {
    static func map(_ user: User) -> LoginController<UUID>.User {
        .init(id: user.id, hashedPassword: user.hashedPassword)
    }
}

// MARK:  Functional operators
infix operator .*: AdditionPrecedence

private func .*<T>(lhs: T, rhs: (inout T) -> Void) -> T {
    var copy = lhs
    rhs(&copy)
    return copy
}

precedencegroup PipePrecedence {
    associativity: left
    lowerThan: LogicalDisjunctionPrecedence
}

infix operator |> : PipePrecedence
func |><A, B>(lhs: A, rhs: (A) -> B) -> B {
    rhs(lhs)
}

typealias Throwing<A, B> = (A) throws -> B
typealias Mapper<A, B> = (A) -> B

infix operator |>>
private func |>><A, B, C>(lhs:  @escaping Throwing<A, B?>, rhs: @escaping Mapper<B, C>) -> Throwing<A, C?> {
    return { a in
        try lhs(a).map(rhs)
    }
}

private func |>><A, B, C>(lhs:  @escaping Throwing<A, B>, rhs: @escaping Mapper<B, C>) -> Throwing<A, C> {
    return { a in
        let b = try lhs(a)
        return rhs(b)
    }
}

private func isNotNil<T>(_ value: T?) -> Bool { value != nil }
