class UnsafieCloudError(Exception):
    pass


class AuthError(UnsafieCloudError):
    pass


class ForbiddenError(UnsafieCloudError):
    pass


class NotFoundError(UnsafieCloudError):
    pass


class ConflictError(UnsafieCloudError):
    pass
