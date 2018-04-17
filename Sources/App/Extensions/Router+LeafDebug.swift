import Routing
import Vapor
import Leaf

protocol TemplateContext: class, Content {
	var user: UserProfile? { get set }
}

final class EmptyTemplateContext: TemplateContext {
	var user: UserProfile?
	
	static func contextGetter(_ req: Request) throws -> Future<EmptyTemplateContext> {
		return .map(on: req) {
			return EmptyTemplateContext()
		}
	}
}


extension Router {
	func getTemplate<T>(
		_ path: DynamicPathComponentRepresentable...,
		template: String,
		contextGetter: @escaping (_ req: Request) throws -> Future<T>
	) where T: TemplateContext {
		func contextWithUser(_ req: Request) throws -> Future<T> {
			return try contextGetter(req).map { context in
				if let userOpt = try? req.authenticated(UserAccount.self),
				   let user = userOpt
				{
					context.user = try! user.getProfile()
				}
				
				return context
			}
		}
		
		// GET /foo -> View
		let pathComponents = path.makeDynamicPathComponents()
		on(.GET, at: pathComponents) { req -> Future<View> in
			return try contextWithUser(req).flatMap(to: View.self) { context -> Future<View> in
				return try (req.view() as TemplateRenderer).render(template, context)
			}
		}
		
		// FIXME: What's the proper way to access env.isRelease here?
		if Environment.get("prod") == nil {
			// GET /foo/json -> JSON
			let jsonComponents = DynamicPathComponent.constant(PathComponent(string: "json")).makeDynamicPathComponents()
			on(.GET, at: pathComponents + jsonComponents) { req -> Future<T> in
				return try contextWithUser(req)
			}
		}
	}
}
