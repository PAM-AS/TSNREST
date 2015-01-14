# Validation
TSNREST has an object validation feature. This is used to validate objects before sending them to the server. This is useful to avoid unnecessary roundtrips to the server for issues that the client can fix itself.

## Creating a validation block
You can create a validation block for each object map, like this:
```objective-c
[(TSNRESTObjectMap *)productMap setValidationBlock:^BOOL(NSManagedObject *object) {
  Product *product = (Product *)object;
  if (product.price.intValue <= 0)
    return NO;
  return YES;
  }];
```
Here we create a validation block that makes sure that a product will always have a price before being uploaded.

## What happens when validation fails
If you try to save an object but validation fails, the failure block of the save operation will be called.

Note: In the future we hope to add an error to the failure block so that you can differentiate between validation errors and other errors.

## Check validity manually
If you want to for example display a warning in your UI if your object is invalid, you can do so by calling `object.isValid`. This calls the validation block in-line and returns the boolean result.
