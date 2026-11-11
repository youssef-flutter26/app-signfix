const serviceArea = require('../../services/serviceAreaService');

async function validate(req, res, next) {
  try {
    if (req.body.locationError) {
      return res.status(422).json({
        error: serviceArea.locationErrorMessage(req.body.locationError),
        errorCode: req.body.locationError.toUpperCase(),
      });
    }

    return res.json({
      data: await serviceArea.validateLocation(
        req.body.latitude,
        req.body.longitude,
        req.user,
      ),
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = { validate };
