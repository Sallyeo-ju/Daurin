export class CreateAddressDto {
  street!: string;
  city!: string;
  province!: string;
  postalCode!: string;
  rt?: string;
  rw?: string;
  isDefault?: boolean;
}