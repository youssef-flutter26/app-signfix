/// Shared state passed across all registration steps
class TechRegistrationData {
  // Step 1 — Personal
  String fullName       = '';
  String mobile         = '';
  String email          = '';
  String dateOfJoining  = '';
  String? profilePhotoPath;

  // Step 2 — Employment
  String employeeId     = '';
  String workLocation   = '';
  List<String> skills   = [];

  // Step 3 — Security
  String password       = '';
  bool   termsAccepted  = false;

  // OTP
  String registrationVerificationToken = '';

  Map<String, dynamic> toPayload() => {
    'full_name':               fullName,
    'mobile':                  mobile,
    if (email.isNotEmpty) 'email': email,
    if (employeeId.isNotEmpty) 'employee_id': employeeId,
    'date_of_joining':         dateOfJoining,
    'work_location':           workLocation,
    'skills':                  skills,
    'password':                password,
    'registration_verification_token': registrationVerificationToken,
    'terms_accepted':          termsAccepted,
  };
}
